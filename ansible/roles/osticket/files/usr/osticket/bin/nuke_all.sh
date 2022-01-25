#!/bin/bash
# Start fresh with all docker imges, containers and volumes gone...

cd $(dirname $0)
. log_utils
cd ..
application_name=${PWD##*/}
cd ../..
export DOCKER_CTX=${PWD}
deployment_config=${DOCKER_CTX}/etc/${application_name}/deploy/deployment.cnf
[ ! -e "${deployment_config}" ] && log_fatal 71 "${deployment_config} not found"

#export "$(grep -v '^#' "${deployment_config}" | xargs -d "\n")
. ${deployment_config}
deployment=${DEPLOYMENT:-unknown deployment}
log_logging_application="MGM/${application_name}(${deployment})" 

name_key=${application_name}


echo "This script will remove all imges, containers and volumes"
__RED='\033[0;31m'
__NC='\033[0m' # No Color
echo -e "${__RED}WARNING: Nothing will be left of ${application_name}!!!${__NC}"

quit=true
read -r -p "Are you sure? [y/N] " response
response=${response,,}    # tolower
if [[ "$response" =~ ^(yes|y)$ ]]
then
   quit=false
fi

if $quit
then
    echo "quiting ..."
    exit 0
fi

log_info "Runing nuke all for ${application_name}"

log_info "Stopping all containers"
./usr/${application_name}/bin/stop.sh


for continer in $(docker ps -a | grep "_${name_key}" | awk '{print $1}')
do
    if docker rm ${container}
    then
	log_info "Removed container ${container}"
    else
	log_error "Failed to remove container ${container}"

    fi
done


for image in $(docker images | grep "${name_key}" | awk '{print $1}')
do
    
    if docker rmi ${image}
    then
	log_info "Removed docker image ${image}"
    else
	log_warn "Failed to remove docker image ${image} - will try to force removal"
    fi
done
for image in $(docker images | grep "${name_key}" | awk '{print $1}')
do
    
    if docker rmi -f ${image}
    then
	log_info "Removed docker image ${image} with force option"
    else
	log_error "Failed to remove docker image ${image} with force option..."
    fi
done

for volume in $(docker volume ls | grep "${name_key}_" | awk '{print $2}')
do
    if docker volume rm ${volume}
    then
	log_info "Removed volume ${volume}"
    else
	log_error "Failed to removed volume {$volume}"
    fi
done

for volume_dir in ./var/volumes/${application_name}_*
do
    if sudo rm -rf ${volume_dir}
    then
	log_info "Removed volume direcotry ${volume_dir}"
    else
	log_error "Failed to removed volume direcotry ${volume_dir}"
    fi
done



