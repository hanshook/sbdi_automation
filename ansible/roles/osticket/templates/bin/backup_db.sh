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

log_info "Saving database dump as ${MYSQL_DATABASE}.sql"
if docker exec $MYSQL_HOST mysqldump --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE > ${MYSQL_DATABASE}_dump.sql
then
    log_info "Sucessfully dumped database"
else
    log_fatal 1 "Failed to dump database"
fi
mv -b ${MYSQL_DATABASE}_dump.sql ${MYSQL_DATABASE}.sql
log_info "Saved database dump as ${MYSQL_DATABASE}.sql"
