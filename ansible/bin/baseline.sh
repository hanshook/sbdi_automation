#! /bin/bash

cd $(dirname $0)
cd ..
echo "Establish a basline of all host after setup"
ansible-playbook deploy.yml
ansible-playbook local_ssh.yml
ansible-playbook setup_admin_users.yml
# do not: ansible-playbook harden.yml
ansible-playbook setup.yml
