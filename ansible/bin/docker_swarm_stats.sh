#! /bin/bash



cd $(dirname $0)
cd ..
ansible docker_swarm -a "docker stats --no-stream"


