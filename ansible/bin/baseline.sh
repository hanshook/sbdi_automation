#! /bin/bash

# TBD: Add verbose output from Ansible!
verbose=""

# NRM blocks DNS, i.e. 1.1.1.1 is not accessile
# It this scritp is run with option -nrm
# This script will deploy using NRMs DNS servers
# Note! It is unknown if this is acceptable because those
# DNS servers will not be present in the cloud.

nrm=false 

while true 
do
    case $1 in
	-v) verbose="-v"
	    shift
	    ;;
	-nrm) nrm=true
	      shift
	      ;;
	*) break	    
	   ;;
    esac
done

cd $(dirname $0)
cd ..
echo "Establish a basline of all host after setup."
echo "Starting at $(date)"
SECONDS=0

if $nrm
then
    ansible-playbook nrm_deploy.yml || exit 1
else
    ansible-playbook deploy.yml || exit 1
fi
ansible-playbook local_ssh.yml || exit 1
ansible-playbook admin_users.yml || exit 1
# TODO: When to harden and how to reverse?
# For the time beeing do not do: ansible-playbook harden.yml
ansible-playbook setup.yml || exit 1
ansible-playbook docker_storage.yml || exit 1
ansible-playbook backup.yml || exit 1
ansible-playbook nagios_server.yml || exit 1
ansible-playbook docker.yml || exit 1
ansible-playbook nagios_monitoring.yml || exit 1
#ansible-playbook docker_apps.yml

duration=$SECONDS
echo "Basline completed at $(date)"
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
