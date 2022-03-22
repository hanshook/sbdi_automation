#! /bin/bash

# TBD: Add verbose output from Ansible!
verbose=""

inventory_arg=""
inventory="default"

while true 
do
    case $1 in
	-v) verbose="-v"
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


ansible-playbook deploy.yml $inventory_arg  || exit 1
ansible-playbook local_ssh.yml $inventory_arg || exit 1
ansible-playbook admin_users.yml $inventory_arg || exit 1
# TODO: When to harden and how to reverse?
# For the time beeing do not do:
# ansible-playbook harden.yml $inventory_arg || exit 1
ansible-playbook initial_setup.yml  $inventory_arg || exit 1
ansible-playbook storage.yml $inventory_arg  || exit 1
ansible-playbook docker.yml  $inventory_arg || exit 1
ansible-playbook backup.yml  $inventory_arg || exit 1
ansible-playbook nagios.yml  $inventory_arg || exit 1
ansible-playbook ipsec_access.yml $inventory_arg || exit 1
#ansible-playbook docker_apps.yml $inventory_arg

duration=$SECONDS
echo "Basline completed at $(date)"
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
