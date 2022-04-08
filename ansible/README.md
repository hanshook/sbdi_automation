# Ansible playbooks

## Overview

This repository contains Ansible playbooks for:

* Deploing all virtual servers, including access gateways
* Setting up access vi ssh
* Setting up and administrate admin users on all servers
* Configuring security 
* Installing software and configuring servers
* ...

## Execution

1. Prepare your host (i.e. prepare /etc/hosts): ```ansible-playbook local_resolve.yml --ask-become-pass```

2. Deploy vms, setup netorking and data volumes: ```ansible-playbook deploy.yml``` 

3. Setup localhost for ssh access: ```ansible-playbook local_ssh.yml```

4. Setup admin users: ```ansible-playbook admin_users.yml```

5. "Harden" deployment (for now remove ubuntu user) : ```ansible-playbook harden.yml``` 

6. Install software, update and configure servers and gateways: ```ansible-playbook initial_setup.yml```

7. NTP syncronized time: ```ansible-playbook ntp.yml```

8. Setup storage for docker data and configuration: ```ansible-playbook storage.yml```

9. Setup Docker and Docker Swarm: ```ansible-playbook docker.yml```

10. Setup backup: ```ansible-playbook backup.yml```

11. Setup Nagios monitoring: ```ansible-playbook nagios.yml```

12. Setup IPSEC VPN access: ```ansible-playbook ipsec_access.yml```

13. Setup Docker Applications (work in progress): ```ansible-playbook docker_apps.yml```

TODO: Setup logging and log analysis

Note: To do all of the above (except step 1 and 5) run  ```ansible/bin/basline.sh```

## Undeploy everyting

In order to remove all hosts and networking run:  ```ansible-playbook undeploy.yml``` 

Note! Data vaolumes are not removed!

## Admin user management

Manage admin users: ```ansible-playbook manage_admin_users.yml```

## Edit vault data

Edit vault. ```export EDITOR=emacs; ansible-vault edit group_vars/all/vault```

Change to your prefered editor in: export EDITOR=/usr/bin/emacs


### Usefull options

Dry-run: ```ansible-playbook <playbook>.yml --check```

Run on a specific host: ```ansible-playbook <playbook>.yml -l inventory_hostname```

Run on a specific group: ```ansible-playbook <playbook>.yml -l servers```

Run on a specific tag: ```ansible-playbook <playbook>.yml --tags nagiosclient```


## References

https://docs.ansible.com/ansible/latest/collections/openstack/cloud/server_module.html



## Prerequsites

Currently the playbooks will run if gnu pass is installed and there exists an executable file ```~/.bin/ansible-vault-pass.sh```
with the following content:

```
#!/bin/sh
pass show ansible-vault-password

```

To install pass: ```sudo apt-get install pass```

You need a personal GPG key.

If you do not have one generate one with: ```gpg --gen-key```

Create a password store with: ```pass init "...your email from your GPG key"```

Add the ansible-vault-password to the password store with: ```pass insert ansible-vault-password```


Som info on password is found [here](https://www.passwordstore.org/).

Finally add a private (do not check into github) vault file ```group_vars/all/become.yml``` with
your sudo password.

Do this by:

```
touch group_vars/all/become.yml
ansible-vault encrypt group_vars/all/become.yml
export EDITOR=emacs; ansible-vault edit group_vars/all/become.yml

```
Now edit in the following content in the file:

```
ansible_become_pass: <your sudo password here>

```

Finally save the vault file.

Whith this setup it should be possible to run the playbooks (safely) without manually entering sudo passwords and vault passwords.

Note:

You may alternative run the playbooks with ```--ask-become-pass```.

You may also run the playbooks and get prompted for the vault password after chaning the  file ```ansible.cfg```  from


```
...
#ask_vault_pass = True
vault_password_file = ~/.bin/ansible-vault-pass.sh
...

```

to

```
...
ask_vault_pass = True
#vault_password_file = ~/.bin/ansible-vault-pass.sh
...

```
