#! /bin/bash
cd $(dirname $0)
{% if standalone_deployment  %}
. log_utils
{% else %}
. /opt/sbdi/lib/log_utils
{% endif %}

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

cd ${DOCKER_CTX}/etc/${application_name}

export CURRENT_USER=$(id -u):$(id -g)

{% if swarm_deployment %}

log_info "Removing docker swarm stack ${application_name}"
docker stack rm ${application_name}

{% else %}

log_info "Stopping docker service ${application_name}"
docker-compose down

{% endif %}
