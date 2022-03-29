#! /bin/bash
cd $(dirname $0)

. /opt/sbdi/lib/log_utils

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

cd ${DOCKER_CTX}/etc/${application_name}

export CURRENT_USER=$(id -u):$(id -g)

log_info "Deploying docker swarm stack ${application_name}"
if docker stack deploy --compose-file=docker-compose.yml ${application_name}
then
    log_info "Deployed docker swarm stack ${application_name} - OK"
else
    log_fatal 96 "Failed to deploy docker swarm stack ${application_name}"
fi
