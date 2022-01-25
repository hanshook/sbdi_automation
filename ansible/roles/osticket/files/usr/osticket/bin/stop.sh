#! /bin/bash
cd $(dirname $0)
. log_utils
cd ..
application_name=${PWD##*/}
cd ../..
export DOCKER_CTX=${PWD}
deployment_config=${DOCKER_CTX}/etc/${application_name}/deploy/deployment.cnf
[ ! -e "${deployment_config}" ] && log_fatal 71 "${deployment_config} not found"

#export $(grep -v '^#' "${deployment_config}" | xargs -d "\n")
. ${deployment_config}
deployment=${DEPLOYMENT:-unknown deployment}
log_logging_application="MGM/${application_name}(${deployment})" 

cd ${DOCKER_CTX}/etc/${application_name}

export CURRENT_USER=$(id -u):$(id -g)

log_info "Shutting down docker service ${application_name}"
docker-compose down
