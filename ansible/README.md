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

2. Deploy vms: ```ansible-playbook deploy.yml```

3. Setup localhost for ssh access: ```ansible-playbook local_ssh.yml```

4. Setup admin users: ```ansible-playbook setup_admin_users.yml```

5. "Harden" deployment (for now remove ubuntu user) : ```ansible-playbook harden.yml```

6. Manage admin users: ```ansible-playbook manage_admin_users.yml```

6. Install software and configure servers and gateways: ```ansible-playbook setup.yml```

7. ... TBD



Dry-run: ```ansible-playbook <playbook>.yml --check```

Run on a specific host: ```ansible-playbook <playbook>.yml -l <fqdn>```

Run on a specific group: ```ansible-playbook <playbook>.yml -l servers```

Run on a specific tag: ```ansible-playbook <playbook>.yml --tags nagiosclient```



Edit vault. ```export EDITOR=emacs; ansible-vault edit group_vars/all/vault```

Change to your prefered editor in: export EDITOR=/usr/bin/emacs



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

To setup a password store follow instructions in this [link](https://www.passwordstore.org/).

With a password store in place finally add the ```ansible-vault-password``` to it.

Also add a private (do not check into github) vault file ```group_vars/all/become.yml``` with
your sudo password, i.e. with the (*encrypted*) content:

```
ansible_become_pass: <your sudo password here>

```

Whith this setup it should be possible to run the playbooks (safely) without manually entering sudo passwords and vault passwords.

Note:

You may alternative run the playbooks with ```--ask-become-pass``` after chaning the  file ```ansible.cfg```  from


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