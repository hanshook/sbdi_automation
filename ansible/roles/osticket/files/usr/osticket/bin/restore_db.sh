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

export BACKUP_CTX=${DOCKER_CTX}/var/backup/${application_name}

[ ! -d ${BACKUP_CTX} ] && log_fatal 9 "No backup context (${BACKUP_CTX}) found" 

cd ${DOCKER_CTX}/etc/${application_name}

export $(grep -v '^#' env/.envosticket | xargs)

[ -z "$MYSQL_HOST" ] &&  log_fatal 91 "MYSQL_HOST not in ./env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 92 "MYSQL_DATABASE not in ./env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 93 "MYSQL_ROOT_PASSWORD not in ./env file" 

cd ${BACKUP_CTX}

[ ! -e "${MYSQL_DATABASE}.sql" ] &&  log_fatal 81 "${MYSQL_DATABASE}.sql does not exist"

log_info "Resoring database dump ${MYSQL_DATABASE}.sql"
docker exec -i $MYSQL_HOST mysql --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ${MYSQL_DATABASE}.sql


