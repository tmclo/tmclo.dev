+++
title = "How to setup a HA Hugo Stack with AWS, Terraform, Ansible, Docker Swarm, Nginx, Traefik & EBS"
date = "20-04-2022"
author = "Tom McLoughlin"
description = "How to use Terraform and Ansible with AWS to setup a high availability Hugo blog cluster"
+++

So I decided to finally setup my hugo blog to share my journey through programming and systems 
administration, to do so I decided I would require some form of redundancy;
if one server for some reason fails or goes offline, I wouldn't want my whole website to go with it, on 
the other hand I have already been running a Docker Swarm cluster for various other projects
so deploying it would be a breeze, however I wanted to demonstrate my journey and share how you too can 
setup your own redundant hugo site!

# Prerequisites

- An AWS account (or any other cloud provider, take note the code I share here is written for deployment 
with AWS)
- [**Terraform**](https://www.terraform.io) installed on your machine
- [**Ansible**](https://www.ansible.com) installed on your machine
- [**VS Code**](https://code.visualstudio.com) or any other text editor for editing a small amount of 
code
- A domain name

# Step 1: Getting setup

First of all I have stored all the code for this project over at my 
[**Github**](https://github.com/tmclo/hugo-stack) so first go ahead and clone that to wherever you wish 
on your machine

```terminfo
git clone https://github.com/tmclo/hugo-stack.git
```

Once you have done that, you should be able to open the `main.tf` file, we will need to potentially edit 
a few things in here before we can setup our infrastructure

At the very top of the file look for line `11` and edit the `shared_credentials_file` location, you must 
set the file path to the location on your disk where your AWS keys are located, this enables us to 
communicate with AWS and deploy the infrastructure.

Next, take a look at line `14`, you will need to change the `public_key` location to the area where your 
public SSH key is stored on your disk.

Once we have done the following, we're good to go, however this configuration I have provided only 
created 2 AWS A1.medium instances, if you wish to add more, you should copy and modify the 
`aws_instance.docker2` block and update it accordingly, you must also copy and paste the 
`aws_volume_attachment.ebs_att2` and update it so that it attached the EBS volume to your additional 
instances.

Assuming all is in order, we're ready to start deploying our infrastructure!

Run the following command to initialise Terraform,
```terminfo
terraform init
```

This command must be run in the same directory as our project, so please ensure you have a terminal 
opened in the correct directory before hand!

Next, lets check what changes we're going to make before actually potentially causing any damage, we can 
do this using the plan command as follows,
```terminfo
terraform plan
```

Check over everything on the output of this command before continuing, we don't want to accidentally 
destroy something we're not supposed to!

Next, let's fire up the infrastructure ready for setting up our cluster!
Run the following command and confirm when asked to do so :)
```terminfo
terraform apply
```

This might take a while but right now is the perfect time for a coffee while we wait for our 
infrastructure to be deployed!

Once thats complete we're done with Terraform! we can now move on to using Ansible to actually deploy 
our project!

# Step 2: Deploy the swarm with Ansible

Now before we get started with ansible, have you noticed we have a new file named `ips` that was created 
during the terraform process?
Good! This file contains all the ips for our instances, a good rule of thumb is to place the ip on the 
first line of this file as our "manager" node and the remaining ips below that into the "workers" 
section of our hosts file

Once you've updated the hosts file accordingly we're ready to fire up ansible and get our docker swarm 
setup

To do this we will be running the following command
```terminfo
ansible-playbook -i hosts -u ubuntu --private-key "~/.ssh/id_ed25519" docker-swarm.yml
```

Take extra note of the `--private-key` section in this command, you will need to update that with the 
correct location of your SSH PRIVATE KEY.

Once you have set the correct location of your private key we're ready to press return and wait for the 
successful deployment of our docker swarm, this will configure each node in the swarm and initialise all 
the connections required for the swarm, we don't even need to login!

Now that ansible has completed, you should be able to login to the first (manager) node and type the 
following command:
```terminfo
docker node ls
```

Provided that ansible has successfully setup the swarm you should see all the nodes that we created 
earlier listed in the output, this means our swarm is working!

# Step 3: Deploy the Hugo stack with ansible

Now that we have a docker swarm setup successfully we can now instruct Ansible to login to our manager 
node for us and setup the entire Hugo cluster, to do this we first need to modify a few things in the 
`docker-compose.yml` file

However to speed things up, we can just run the following command first leaving only two things to 
update in our docker compose file,

```terminfo
sed -i 's/example.com/new-domain.com/g' docker-compose.yml
```

This command looks for the occurance of "example.com" and changes it to our actual domain.

Once we've done that we need to edit the file and look for the sections where we need to edit out 
cloudflare API details

Look for the following,

- ***CLOUDFLARE EMAIL***
- ***CLOUDFLARE DNS API***

Once these are updated we're ready to deploy our cluster by running the following command,

```terminfo
ansible-playbook -i hosts -u ubuntu --private-key "~/.ssh/id_ed25519" docker-deploy.yml
```

Once that's finished you should be left with a fully functional Hugo stack on your brand new docker 
swarm cluster!

Thank you for reading!
