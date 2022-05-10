#! /bin/bash
cd $(dirname $0)
. /opt/sbdi/lib/log_utils

backup=""
while true 
do
    case $1 in
	-from)
	    backup=$2
	    shift
	    shift
	    ;;
	*) break	    
	   ;;
    esac
done


[ $EUID -eq 0 ] && log_fatal 88 "Do *not* run as root"
if ! id -nG "$USER" | grep -qw "docker"
then
    log_fatal 88 "User must belong to group 'docker'"
fi

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

env_file="${DOCKER_CTX}/etc/${application_name}/env/.env${application_name}"

[ ! -e "${env_file}" ] && log_fatal 91 "env file does not exist: ${env_file}" 

export $(grep -v '^#' ${env_file} | xargs)

MYSQL_HOST=${WORDPRESS_DB_HOST%:*} # grab everything up to first ':' (if port in config)
MYSQL_DATABASE=${WORDPRESS_DB_NAME}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

[ -z "$MYSQL_HOST" ] &&  log_fatal 92 "MYSQL_HOST not in env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 93 "MYSQL_DATABASE not in env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 94 "MYSQL_ROOT_PASSWORD not in env file"


export BACKUP_CTX=${DOCKER_CTX}/var/backup/${application_name}

[ ! -d ${BACKUP_CTX} ] && log_fatal 95 "No backup context found: ${BACKUP_CTX}" 

cd ${BACKUP_CTX}

if [ ! -z "${backup}" ]
then
    [ ! -d ${backup} ] && log_fatal 96 "No backup found: ${BACKUP_CTX}/${backup}"
    cd ${backup}
    log_info "Selected backup ${backup}"
else
    log_info "Select standard backup"
fi

[ ! -e "${MYSQL_DATABASE}.sql" ] &&  log_fatal 96 "${MYSQL_DATABASE}.sql does not exist"

SERVICE_NAME="${application_name}_${MYSQL_HOST}"

log_info "Restoring database dump ${BACKUP_CTX}/${MYSQL_DATABASE}.sql to ${SERVICE_NAME}"
if /opt/sbdi/bin/service_exec -i $SERVICE_NAME mysql --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ${MYSQL_DATABASE}.sql
then
    log_info "Restored database dump $(pwd)/${MYSQL_DATABASE}.sql to ${SERVICE_NAME}"
else
    log_fatal 1 "Failed to restored database dump $(pwd)/${MYSQL_DATABASE}.sql to ${SERVICE_NAME}"
fi


