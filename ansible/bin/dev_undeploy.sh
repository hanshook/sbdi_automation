#! /bin/bash

cd $(dirname $0)
cd ..
ansible-playbook undeploy.yml -i dev
