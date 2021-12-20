# Ansible playbooks

## Overview

This repository contains Ansible playbooks for:

* Deploing all virtual servers, including access gateways
* Setting up access vi ssh
* Setting up users on all servers with passwords
* ...

## Execution

Install and configure: ```ansible-playbook <playbook>.yml```

Dry-run: ```ansible-playbook <playbook>.yml --check```

Run on a specific host: ```ansible-playbook <playbook>.yml -l <fqdn>```

Run on a specific group: ```ansible-playbook <playbook>.yml -l servers```

Run on a specific tag: ```ansible-playbook <playbook>.yml --tags nagiosclient```


Edit vault. '''export EDITOR=emacs; ansible-vault edit group_vars/all/vault'''
# Do not forget: export EDITOR=/usr/bin/emacs



https://docs.ansible.com/ansible/latest/collections/openstack/cloud/server_module.html




