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

export BACKUP_CTX=${DOCKER_CTX}/var/backup/${application_name}

[ ! -d ${BACKUP_CTX} ] && log_fatal 9 "No backup context (${BACKUP_CTX}) found" 

cd ${DOCKER_CTX}/etc/${application_name}

export $(grep -v '^#' env/.envosticket | xargs)

[ -z "$MYSQL_HOST" ] &&  log_fatal 91 "MYSQL_HOST not in ./env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 92 "MYSQL_DATABASE not in ./env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 93 "MYSQL_ROOT_PASSWORD not in ./env file" 

cd ${BACKUP_CTX}

[ ! -e "${MYSQL_DATABASE}.sql" ] &&  log_fatal 81 "${MYSQL_DATABASE}.sql does not exist"

log_info "Restoring database dump ${MYSQL_DATABASE}.sql"
if docker exec -i $MYSQL_HOST mysql --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ${MYSQL_DATABASE}.sql
then
    log_info "Restored database dump ${MYSQL_DATABASE}.sql"
else
    log_fatal 1 "Failed to restored database dump ${MYSQL_DATABASE}.sql"
fi


