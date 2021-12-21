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

5. "Harden" deployment (for now remove ubuntu user) : ```ansible-playbook harden.yml --ask-become-pass```

6. Manage admin users: ```ansible-playbook manage_admin_users.yml --ask-become-pass```

6. Install software and configure servers and gateways: ```ansible-playbook setup.yml --ask-become-pass```

7. ... TBD



Dry-run: ```ansible-playbook <playbook>.yml --check```

Run on a specific host: ```ansible-playbook <playbook>.yml -l <fqdn>```

Run on a specific group: ```ansible-playbook <playbook>.yml -l servers```

Run on a specific tag: ```ansible-playbook <playbook>.yml --tags nagiosclient```


Edit vault. ```export EDITOR=emacs; ansible-vault edit group_vars/all/vault```
# Change to your prefered editor in: export EDITOR=/usr/bin/emacs


## References

https://docs.ansible.com/ansible/latest/collections/openstack/cloud/server_module.html




