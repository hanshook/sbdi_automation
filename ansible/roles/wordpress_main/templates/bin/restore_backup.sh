#! /bin/bash
cd $(dirname $0)
. /opt/sbdi/lib/log_utils

restore_db=true
restore_files=true
backup=""
while true 
do
    case $1 in
	-nodb)
	    restore_db=false
	    shift
	    ;;
	-nofiles)
	    restore_files=false
	    shift
	    ;;
	-from)
	    backup=$2
	    shift
	    shift
	    ;;	
	*) break	    
	   ;;
    esac
done

site=${1:-"main"}

	  

[ $EUID -eq 0 ] && log_fatal 88 "Do *not* run as root"
if ! id -nG "$USER" | grep -qw "docker"
then
    log_fatal 88 "User must belong to group 'docker'"
fi

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

case $site in
    main) ;;
    tools) ;;
    docs) ;;
    *) log_fatal 90 "site (${site} must be one of 'main', 'tools' or 'docs'" ;;
esac

log_info "Will attempt to restore backup for site ${site}"

base_application_name="${application_name%_*}" # '_main' in application_name
                                               # -> grab everything up to first '_' 
env_file_name=".env${base_application_name}_${site}"  
env_file="${DOCKER_CTX}/etc/${application_name}/env/${env_file_name}"

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
    
if ! $restore_db
then
    log_info "Skipping db restore"
else
    # Restore database
    # ===============


    ARTEFACT=${site}-wordpress-db.sql
    ARTEFACT_NAME="database dump"

    SERVICE_NAME="${application_name}_${MYSQL_HOST}"
    #    SERVICE_NAME="${application_name%_*}_${MYSQL_HOST}"

    [ ! -e "${ARTEFACT}" ] &&  log_fatal 96 "${ARTEFACT_NAME} $(pwd)/${ARTEFACT} does not exist"
    
    log_info "Restoring ${ARTEFACT_NAME} to ${SERVICE_NAME} from $(pwd)/${ARTEFACT}"
    if /opt/sbdi/bin/service_exec -i $SERVICE_NAME mysql --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ${ARTEFACT}
    then
	log_info "Restored ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} to ${SERVICE_NAME}"
    else
	log_fatal 1 "Failed to restored ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} to ${SERVICE_NAME}"
    fi
fi

if ! $restore_files
then
    log_info "Skipping files restor"
else
    # Restoring files in /var/www/html
    # ===============================


    WORDPRESS_HOST="wordpress-${site}" 
    BACKUP_TARBALL_NAME=${site}-wordpress-files
    
    ARTEFACT=${BACKUP_TARBALL_NAME}.tgz
    ARTEFACT_NAME="/var/www/html tarball"

    SERVICE_NAME="${application_name}_${WORDPRESS_HOST}"
    #    SERVICE_NAME="${application_name%_*}_${WORDPRESS_HOST}"

    [ ! -e "${ARTEFACT}" ] &&  log_fatal 96 "${ARTEFACT_NAME} $(pwd)/${ARTEFACT} does not exist"

    log_info "Restoring ${ARTEFACT_NAME} to ${SERVICE_NAME} from  $(pwd)/${ARTEFACT}"
    if /opt/sbdi/bin/service_exec -i $SERVICE_NAME tar xz -C / < ${ARTEFACT}
    then
	log_info "Restored ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} on ${SERVICE_NAME}"
    else
	log_fatal 2 "Failed to restore ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} on ${SERVICE_NAME}"
    fi
fi
