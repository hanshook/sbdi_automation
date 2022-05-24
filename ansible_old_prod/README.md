# Ansible playbooks

## Overview

This repository contains 'helper' Ansible playbooks for the 'current' SBDI deployment that until now has not been managed by Ansible.

Ther are currently playbooks for

* Deploing new virtual servers for cassandra and solr
* Setting up access vi ssh to the current prod env
* Setting up and administrate admin users on servers
* ...

## Execution


1. Deploy new vms: ```ansible-playbook deploy.yml``` 

2. Manual step required, update invetory file with floating ip's

3. Prepare your host for access (i.e. prepare /etc/hosts): ```ansible-playbook local_resolve.yml```
   Note: If your password is diffrent on your local machine ```group_vars/all/become.yml``` may need updating.

4. Setup localhost for ssh access: ```ansible-playbook local_ssh.yml```

5. Setup admin users: ```ansible-playbook admin_users.yml```

6. Install software, update and configure servers and gateways: ```ansible-playbook initial_setup.yml```

7. Setup Docker on new virtual machines: ```ansible-playbook docker.yml```

8. Setup storage for docker data volumes: ```ansible-playbook storage.yml```

Also in the workse are:

9. Setup Nagios monitoring: ```ansible-playbook nagios.yml```

## Edit vault data

Edit vault. ```export EDITOR=emacs; ansible-vault edit group_vars/all/vault```

Change to your prefered editor in: export EDITOR=/usr/bin/emacs

## Prerequsites

Same as for ../ansible
