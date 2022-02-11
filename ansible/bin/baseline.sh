#! /bin/bash

cd $(dirname $0)
cd ..
echo "Establish a basline of all host after setup"
ansible-playbook deploy.yml || exit 1
ansible-playbook local_ssh.yml || exit 1
ansible-playbook setup_admin_users.yml || exit 1
# do not: ansible-playbook harden.yml
ansible-playbook setup.yml || exit 1
ansible-playbook docker_storage.yml
ansible-playbook backup.yml
ansible-playbook nagios_server.yml
ansible-playbook nagios_monitoring.yml


