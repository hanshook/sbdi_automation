#! /bin/bash
cd $(dirname $0)

# ========================
# Restore wordpress backup
# ========================

USAGE="USAGE: $0 [-nodb] [-nofiles] [-from <backup name>] all | main | docs | tools"

APPLICATION_PATH=${PWD%/*}
APPLICATION_NAME=${APPLICATION_PATH##*/}
# This wordpress application used to be called worpress_main
# This is expected to be wordpress (since main is a site)
# Therefore we remove the '_main' in APPLICATION_NAME
# This will ensute the operation of this script even after
# the aplication name has been changed
BASE_APPLICATION_NAME="${APPLICATION_NAME%_*}" # -> grab everything up to first '_'

. /opt/sbdi/lib/log_utils
log_logging_application="MGM/${APPLICATION_NAME}"

switches=''
restore_db=true
restore_files=true
backup_name=""
while true 
do
    case $1 in
	-nodb)
	    restore_db=false
	    switches="${switches} -nodb"
	    shift
	    ;;
	-nofiles)
	    restore_files=false
	    switches="${switches} -nofiles"
	    shift
	    ;;
	-from)
	    backup_name=$2
	    switches="${switches} -from $2"
	    shift
	    shift
	    ;;
	-h)
	    echo $USAGE
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

case $site in
    main) ;;
    tools) ;;
    docs) ;;
    all)   ;;
    *) log_fatal 90 "site (${site} must be one of 'main', 'tools' or 'docs'" ;;
esac

if [ "$site" == "all" ]
then
    log_info "Will attempt to restore bakup for all sites"

    for site in main tools docs
    do
	$0 $switches $site
    done
else
    log_info "Will attempt to restore backup for site ${site}" 
fi

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

env_file_name=".env${BASE_APPLICATION_NAME}_${site}"  
env_file="${DOCKER_CTX}/etc/${APPLICATION_NAME}/env/${env_file_name}"

[ ! -e "${env_file}" ] && log_fatal 91 "env file does not exist: ${env_file}" 

export $(grep -v '^#' ${env_file} | xargs)

MYSQL_HOST=${WORDPRESS_DB_HOST%:*} # grab everything up to first ':' (if port in config)
MYSQL_DATABASE=${WORDPRESS_DB_NAME}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

[ -z "$MYSQL_HOST" ] &&  log_fatal 92 "MYSQL_HOST not in env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 93 "MYSQL_DATABASE not in env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 94 "MYSQL_ROOT_PASSWORD not in env file" 


export BACKUP_CTX=${DOCKER_CTX}/var/backup/${APPLICATION_NAME}

[ ! -d ${BACKUP_CTX} ] && log_fatal 95 "No backup context found: ${BACKUP_CTX}" 

cd ${BACKUP_CTX}

if [ ! -z "${backup_name}" ]
then
    [ ! -d ${backup_name} ] && log_fatal 96 "No backup found: ${BACKUP_CTX}/${backup_name}"
    cd ${backup_name}
    log_info "Selected backup ${backup_name}"
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

    SERVICE_NAME="${APPLICATION_NAME}_${MYSQL_HOST}"

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

    SERVICE_NAME="${APPLICATION_NAME}_${WORDPRESS_HOST}"

    [ ! -e "${ARTEFACT}" ] &&  log_fatal 96 "${ARTEFACT_NAME} $(pwd)/${ARTEFACT} does not exist"

    log_info "Restoring ${ARTEFACT_NAME} to ${SERVICE_NAME} from  $(pwd)/${ARTEFACT}"
    if /opt/sbdi/bin/service_exec -i $SERVICE_NAME tar xz -C / < ${ARTEFACT}
    then
	log_info "Restored ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} on ${SERVICE_NAME}"
    else
	log_fatal 2 "Failed to restore ${ARTEFACT_NAME} from $(pwd)/${ARTEFACT} on ${SERVICE_NAME}"
    fi
fi
