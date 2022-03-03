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

cd ${DOCKER_CTX}/var/volumes
for volume in {% for vol in docker_volumes %} {{ vol }} {% endfor %} 
do
    if [ ! -d ${volume} ]
    then
	if sudo mkdir ${volume}
	then
	    log_info "Created empty volume directory ${volume}"
	else
	    log_fatal 2 "Failed to created empty volume directory ${volume}"
	fi
	    
    fi
done

cd ${DOCKER_CTX}/etc/${application_name}

export CURRENT_USER=$(id -u):$(id -g)

{% if swarm_deployment %}

log_info "Deploying docker swarm stack ${application_name}"
docker stack deploy --compose-file=docker-compose.yml ${application_name}

{% else %}

log_info "Starting docker service ${application_name}"
docker-compose up -d

{% endif %}

