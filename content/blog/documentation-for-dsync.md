+++
title = "A better guide to working with Dsync & Dovecot"
date = "03-06-2022"
author = "Tom McLoughlin"
description = "A better documentation for Dsync & dovecot replication"
+++

Hello everyone, recently I have been working with Dsync & dovecot replication in order to make my privately hosted email servers more reduncant; I need constant access to my emails, but I love managing email servers and my own infrastructure so cloud hosted email isn't on my list of choices.

Anyway, whilst looking around for solutions to the issue of replication with dovecot (replicating the maildir's) I was assuming I'd be needing something like DRBD, GlusterFS, Ceph or some other shared file system cluster application, however after a couple minutes research I was surprised to find out that dovecot has replication built into it already!

They call it Dsync and it's surprisingly simple to setup and get working, however the documentation on the other hand isn't very clear and easy to understand, there's not really any form of information on using this alongside a database, and since having a replicated database on both the mail servers is probably the best way to go around managing user accounts for a cluster like this, I started right away with setting up MariaDB replication so both the mail servers have a locally hosted database server with their own replica of the data; this means accessing the database for authentication is as fast as it can be for a setup of this kind, now the database went a breeze and was simple to setup, however once moving onto Dsync the documentation doesn't show that you require a UserDB, PassDB, Password_query, User_query and iterate_query, however I'm going to list a few configuration snippets in order to help demonstrate how you can achieve replication on your own mail servers.

To start off with, we need to enable the replication & notify plugins in ```/etc/dovecot/conf.d/10-mail.conf```
{{< highlight go >}}
mail_plugins = $mail_plugins notify replication
{{</highlight>}}

Now save that file and open up ```/etc/dovecot/conf.d/auth-sql.conf.ext```

We're going to first setup the ```passdb``` block in this file as such:
{{< highlight go >}}
passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}
{{</highlight>}}

Now we need to setup the ```userdb``` block in the same file as such:
{{< highlight go >}}
userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}
{{</highlight>}}

Take note that we also may be replacing the "static" userdb configuration you may already have, if you have it here, delete it as we are going to be using the new "sql" driver configuration for this block.

You may now save the file and open up the file ```/etc/dovecot/dovecot-sql.conf.ext```

We're going to make check for the following lines and make sure they match the following:
{{< highlight go >}}
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';
user_query = SELECT 'vmail' AS uid, 'vmail' AS 'gid', '/var/mail/vhosts/%d/%n' AS home;
iterate_query = SELECT email AS user FROM virtual_users;
{{</highlight>}}

You must edit these lines to fit the structure of your database accordingly.

Now, it's time to setup our replicator, provided you have done the above steps on BOTH OF YOUR MAIL SERVERS, we will be ready to continue.

Now we're going to open the file ```/etc/dovecot/conf.d/10-master.conf```

{{< highlight go >}}
service replicator {
  process_min_avail = 1
  unix_listener replicator-doveadm {
    mode = 0600
    user = vmail
  }
}

service aggregator {
  fifo_listener replication-notify-fifo {
    user = vmail
  }
  unix_listener replication-notify {
    user = vmail
  }
}

plugin {
  replication_sync_timeout = 2
  mail_replica = tcp:mail1.example.com:4000 # CHANGE THIS LINE
}

doveadm_password = supErSeCreTPaS$w0RD123 # change this

service doveadm {
  inet_listener {
    port = 4000
  }
}
{{</highlight>}}

Follow these steps on both mail servers and make sure the mail_replica line is configured with the hostname of the opposite mail server, for example,
If you're on mailserver1(1.0.0.1) you would put mailserver2(1.0.0.2), and if you're on mailserver2(1.0.0.2) you would put mailserver1(1.0.0.1)

Provided you have followed these steps correctly you should now be able to run restart dovecot on both servers and they should begin syncing

{{< highlight terminfo >}}
systemctl restart dovecot
{{</highlight>}}

Now this is perfect because our mail servers are synchronising however, we're missing something VERY important, and that's SSL,
as it's very risky to run this configuration and have our mail servers communicate sensitive information on unencrypted connections.

To setup SSL for our already running cluster, all we need to do is change the lines we added to `/etc/dovecot/conf.d/10-master.conf```

Just add the following lines to the config on both mail servers and restart, please note you must already have a running SSL configuration for your mail servers before attempting this as we will be using the same certificates that are being used for regular IMAPS

{{< highlight go >}}
service doveadm {
  inet_listener {
    port = 4000
    ssl = yes # ADD THIS LINE
  }
}
{{< / highlight >}}

Now once we have done that, we just need to change the following block a little higher up in the same file,
{{< highlight go >}}
plugin {
  replication_sync_timeout = 2
  mail_replica = tcp:mail1.example.com:4000 # CHANGE THIS LINE, USE THE HOSTNAME IN SSL CERT
}
{{< / highlight >}}

We will be adding a single character to this line where we will be changing `tcp` to `tcps`

For example:
{{< highlight go >}}
plugin {
  replication_sync_timeout = 2
  mail_replica = tcps:mail1.example.com:4000 # CHANGE THIS LINE, USE HOSTNAME IN SSL CERT
}
{{< / highlight >}}

You may now restart both servers, please note configuration changes I have demonstrated here must be the same on BOTH servers.

{{< highlight terminfo >}}
systemctl restart dovecot
{{< / highlight >}}

Now check your ```/var/log/mail.log``` and you should see that mail is beginning to sync over SSL

# Using LetsEncrypt??
Dovecot Dsync can have issues when using LetsEncrypt certificates, as the certificates need to include each server you use in your cluster.

For example say we have two servers in our mail cluster,

1.0.0.1 (mail1.example.com)
1.0.0.2 (mail2.example.com)

Our LetsEncrypt certificate will need to include the following domains in the certificate, as such:

{{< highlight terminfo >}}
certbot certonly -d mail.example.com -d mail1.example.com -d mail2.example.com
{{</highlight>}}

However whilst this command looks like it would work easily, since mail1 & mail2 sub-domains are pointing to different servers we cannot issue the certificate and have it properly validated since certbot will only run a HTTP auth server on one of our servers (our master).

This is the error you would be receiving in this case:

{{< highlight terminfo >}}
Error: doveadm server disconnected before handshake: SSL certificate doesn't match expected host name mail1.example.com: did not match to any IP or DNS fields
{{</highlight>}}

## But there's a solution!

If we instead use DNS Auth instead of HTTP Auth with certbot we can achieve the desired certificate including all servers in our cluster, this is also beneficial as without this we would require a multiple certificates for each server without this.

To accomplish this we are going to need to have our domains setup at CloudFlare and an extension for certbot,

Let's start by installing our cloudflare extension for certbot.

{{< highlight terminfo >}}
apt -y install python3-certbot-dns-cloudflare
{{</highlight>}}

Now, create a folder to store our cloudflare API key, unfortunately the cerbot extension doesn't currently support API Tokens, so we will need our Global API key in order to do this.

{{< highlight terminfo >}}
mkdir -p /etc/cloudflare/
touch /etc/cloudflare/cloudflare.ini
{{</highlight>}}

Now we need to populate our cloudflare.ini with the API keys, just change the email and set the Global API key as such:

{{< highlight terminfo >}}
cat <<EOF > /etc/cloudflare/cloudflare.ini
dns_cloudflare_email = mail@example.com
dns_cloudflare_api_key =  CF GLOBAL API KEY HERE
EOF
{{</highlight>}}

Now in order to keep our API keys secure we need to set appropriate permissions on them as such ->

{{< highlight terminfo >}}
chown -R root:root /etc/cloudflare/cloudflare.ini
chmod -R 600 /etc/cloudflare/cloudflare.ini
{{</highlight>}}

That should keep our keys locked down in our system, however there is some ways available to run cerbot as a non-root user so please look into this, as it's far more secure, however I have left root here since it will be the default setup for most people.

next we need to actually issue the certificates, the way I do this is as follows:

{{< highlight bash >}}
certbot certonly \                            
--dns-cloudflare \
--dns-cloudflare-credentials /etc/cloudflare/cloudflare.ini \
-d mail.example.co.uk \
-d mail1.example.co.uk \
-d mail2.example.co.uk
{{</highlight>}}

Once you have ran that we should now have a certificate issued for all our mail sub-domains with DNS Auth (thanks cloudflare!)

I'd recommend setting up a shell script and having that run the above cerbot command in a cronjob every 30 days, and then using rsync to synchronise the certificates to the other servers in our cluster.

You should now be able to restart dovecot on all the machines in the cluster and have no issues with SSL

# Out of Memory

{{< highlight terminfo >}}
dovecot: replicator: Panic: data stack: Out of memory when allocating 268435496 bytes
dovecot: replicator: Error: Raw backtrace: #0 test_subprocess_fork........
{{</highlight>}}

If you're receiving this error and have struggled googling for a solution, even tried vsz_limit on the replicator service, etc.
Well congratulations, you've found a bug!

However, luckily you also found my blog, and I have the solution for you!

The solution here is to just comment out `replication_sync_timeout`, I'm not too sure why this stops this error from happening or what kind of memory leak is going on with the timeout, however it is a viable solution that works, hopefully they will fix this in the future!

{{< highlight terminfo >}}
plugin {
  #replication_sync_timeout = 30
  mail_replica = tcps:mail2.example.com:4000
}
{{</highlight>}}


I hope this helped, thanks for reading!