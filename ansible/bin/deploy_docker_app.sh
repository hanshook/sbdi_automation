#! /bin/bash

# utility scritp that installs just one docker app

cd $(dirname $0)
cd ..
ansible-playbook docker_apps.yml --extra-vars "only_app=$1" --skip-tags "static_html, haproxy"



