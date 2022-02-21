#! /bin/bash
cd $(dirname $0)
{% if deployment_prefix is defined  %}
. /opt/sbdi/lib/log_utils
{% else %}
. log_utils
{% endif %}

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

cd ${DOCKER_CTX}/etc/${application_name}

export CURRENT_USER=$(id -u):$(id -g)

log_info "Shutting down docker service ${application_name}"
docker-compose down
