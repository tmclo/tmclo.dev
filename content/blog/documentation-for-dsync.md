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
```terminfo
mail_plugins = $mail_plugins notify replication
```

Now save that file and open up ```/etc/dovecot/conf.d/auth-sql.conf.ext```

We're going to first setup the ```passdb``` block in this file as such:
```terminfo
passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}
```

Now we need to setup the ```userdb``` block in the same file as such:
```terminfo
userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}
```

Take note that we also may be replacing the "static" userdb configuration you may already have, if you have it here, delete it as we are going to be using the new "sql" driver configuration for this block.

You may now save the file and open up the file ```/etc/dovecot/dovecot-sql.conf.ext```

We're going to make check for the following lines and make sure they match the following:
```terminfo
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';
user_query = SELECT 'vmail' AS uid, 'vmail' AS 'gid', '/var/mail/vhosts/%d/%n' AS home;
iterate_query = SELECT email AS user FROM virtual_users;
```

You must edit these lines to fit the structure of your database accordingly.

Now, it's time to setup our replicator, provided you have done the above steps on BOTH OF YOUR MAIL SERVERS, we will be ready to continue.

Now we're going to open the file ```/etc/dovecot/conf.d/10-master.conf```

```terminfo
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
  mail_replica = tcp:REPLACE WITH THE IP OF YOUR OTHER EMAIL SERVER:4000 # CHANGE THIS LINE
}

doveadm_password = supErSeCreTPaS$w0RD123 # change this

service doveadm {
  inet_listener {
    port = 4000
  }
}
```

Follow these steps on both mail servers and make sure the mail_replica line is configured with the IP Address of the opposite mail server, for example,
If you're on mailserver1(1.0.0.1) you would put mailserver2(1.0.0.2), and if you're on mailserver2(1.0.0.2) you would put mailserver1(1.0.0.1)

Provided you have followed these steps correctly you should now be able to run restart dovecot on both servers and they should begin syncing

```terminfo
systemctl restart dovecot
```

Now this is perfect because our mail servers are synchronising however, we're missing something VERY important, and that's SSL,
as it's very risky to run this configuration and have our mail servers communicate sensitive information on unencrypted connections.

To setup SSL for our already running cluster, all we need to do is change the lines we added to `/etc/dovecot/conf.d/10-master.conf```

Just add the following lines to the config on both mail servers and restart, please note you must already have a running SSL configuration for your mail servers before attempting this as we will be using the same certificates that are being used for regular IMAPS

```terminfo
service doveadm {
  inet_listener {
    port = 4000
    ssl = yes # ADD THIS LINE
  }
}
```

Now once we have done that, we just need to change the following block a little higher up in the same file,
```terminfo
plugin {
  replication_sync_timeout = 2
  mail_replica = tcp:REPLACE WITH THE IP OF YOUR OTHER EMAIL SERVER:4000 # CHANGE THIS LINE
}
```

We will be adding a single character to this line where we will be changing `tcp` to `tcps`

For example:
```terminfo
plugin {
  replication_sync_timeout = 2
  mail_replica = tcps:REPLACE WITH THE IP OF YOUR OTHER EMAIL SERVER:4000 # CHANGE THIS LINE
}
```

You may now restart both servers, please note configuration changes I have demonstrated here must be the same on BOTH servers.

```terminfo
systemctl restart dovecot
```

Now check your ```/var/log/mail.log``` and you should see that mail is beginning to sync over SSL

I hope this helped, thanks for reading!