#! /bin/bash

# TBD: Add verbose output from Ansible!
verbose=""

# NRM blocks DNS, i.e. 1.1.1.1 is not accessile
# It this scritp is run with option -nrm
# This script will deploy using NRMs DNS servers
# Note! It is unknown if this is acceptable because those
# DNS servers will not be present in the cloud.

nrm=false
inventory_arg=""
inventory="default"

while true 
do
    case $1 in
	-v) verbose="-v"
	    shift
	    ;;
	-nrm) nrm=true
	      shift
	      ;;
	-i) inventory=$2
	    inventory_arg="-i $2"
	    shift
	    shift
	    ;;
	*) break	    
	   ;;
    esac
done

cd $(dirname $0)
cd ..
echo "Establish a basline of all host in inventory: ${inventory}"
echo "Starting at $(date)"
SECONDS=0

if $nrm
then
    ansible-playbook nrm_deploy.yml $inventory_arg || exit 1
else
    ansible-playbook deploy.yml $inventory_arg  || exit 1
fi
ansible-playbook local_ssh.yml $inventory_arg || exit 1
ansible-playbook admin_users.yml $inventory_arg || exit 1
# TODO: When to harden and how to reverse?
# For the time beeing do not do: ansible-playbook harden.yml $inventory_arg
ansible-playbook setup.yml  $inventory_arg || exit 1
ansible-playbook docker_storage.yml $inventory_arg  || exit 1
ansible-playbook backup.yml  $inventory_arg || exit 1
ansible-playbook nagios_server.yml  $inventory_arg || exit 1
ansible-playbook docker.yml  $inventory_arg || exit 1
ansible-playbook nagios_monitoring.yml   $inventory_arg || exit 1
#ansible-playbook docker_apps.yml $inventory_arg

duration=$SECONDS
echo "Basline completed at $(date)"
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
