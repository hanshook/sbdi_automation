#! /bin/bash
cd $(dirname $0)

# ================
# Backup wordpress
# ================

USAGE="USAGE: $0 [-nodb] [-nofiles] [-to <backup name>] all | main | docs | tools"

APPLICATION_PATH=${PWD%/*}
APPLICATION_NAME=${APPLICATION_PATH##*/}
# Currently the wordpress application is called worpress_main
# This is expected to be wordpress (since main is a site)
# Therefore remove the '_main' in APPLICATION_NAME
# This will ensute the operation of this script even after
# the aplication name has been changed
BASE_APPLICATION_NAME="${APPLICATION_NAME%_*}" # -> grab everything up to first '_' 

. /opt/sbdi/lib/log_utils
log_logging_application="MGM/${APPLICATION_NAME}"

switches=''
backup_db=true
backup_files=true
backup_name=""

while true 
do
    case $1 in
	-nodb)
	    backup_db=false
	    switches="${switches} -nodb"
	    shift
	    ;;
	-nofiles)
	    backup_files=false
	    switches="${switches} -nofiles"
	    shift
	    ;;
	-to)
	    backup_name=$2
	    switches="${switches} -to $2"
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
    main)  ;;
    tools) ;;
    docs)  ;;
    all)   ;;
    *) log_fatal 90 "site (${site} must be one of 'all', 'main', 'tools' or 'docs'" ;;
esac

if [ "$site" == "all" ]
then
    log_info "Will attempt to backup all sites"

    for site in main tools docs
    do
	$0 $switches $site
    done
else
    log_info "Will attempt to backup site ${site}"
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
    if [ -e ${backup_name} ]
    then
	log_warn "A backup with name ${backup_name} already exists"
    fi
    NEW_BACKUP_DIR=`mktemp -d -p .`
    if chgrp docker ${NEW_BACKUP_DIR} && chmod 770 ${NEW_BACKUP_DIR}
    then
	if mv --backup=numbered -T ${NEW_BACKUP_DIR} ${backup_name}
	then
	    cd ${backup_name}
	else
	    rm -rf ${NEW_BACKUP_DIR}
	    log_fatal 96 "Unable to create backup directory: ${backup_name}, mv --backup=numbered -T ${NEW_BACKUP_DIR} ${backup_name}, error: $?"
	fi
    else
	rm -rf ${NEW_BACKUP_DIR}
	log_fatal 96 "Unable to create backup directory: ${backup_name}, chgrp docker ${NEW_BACKUP_DIR} && chmod 770 ${NEW_BACKUP_DIR}, error: $?"
    fi
    log_info "Using named backup location: $(pwd)"
else
    log_info "Using standard backup location: $(pwd)"
fi

secure_and_save_artefact() {
    
    if chgrp docker new_${ARTEFACT}
    then
	log_info "Secure ownership is now set on ${ARTEFACT_NAME}"
    else
	success=false
	log_warn "Failed to set secure ownership on ${ARTEFACT_NAME} - removing it"
	rm -rf  new_${ARTEFACT}
    fi

    if chmod 660 new_${ARTEFACT}
    then
	log_info "Secure access rights is now set on ${ARTEFACT_NAME}"
    else
	success=false
	log_warn "Failed to set secure access rights on ${ARTEFACT_NAME} - removing it"
	rm -rf  new_${ARTEFACT}
    fi

    if mv --backup=numbered new_${ARTEFACT} ${ARTEFACT}
    then
	log_info "Saved ${ARTEFACT_NAME} as ${ARTEFACT}"
    else
	success=false
	log_warn "Failed to save ${ARTEFACT_NAME} as ${ARTEFACT}"
    fi

}

success=true

if ! $backup_db
then
    log_info "Skipping db backup"
else
    # Backup database
    # ===============


    ARTEFACT=${site}-wordpress-db.sql
    ARTEFACT_NAME="database dump"

    SERVICE_NAME="${APPLICATION_NAME}_${MYSQL_HOST}"

    log_info "Creating ${ARTEFACT_NAME} from ${SERVICE_NAME} and saving it as $(pwd)/new_${ARTEFACT}"
    if /opt/sbdi/bin/service_exec $SERVICE_NAME mysqldump --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE > new_${ARTEFACT}
    then
	log_info "Sucessfully created ${ARTEFACT_NAME}"
	secure_and_save_artefact
    else
	log_warn "Failed to create ${ARTEFACT_NAME} - removing any partial results"
	success=false
	# remove artefact if any
	rm -rf  new_${ARTEFACT}
    fi
fi

if ! $backup_files
then
    log_info "Skipping files backup"
else
    # Backup files in /var/www/html
    # =============================


    WORDPRESS_HOST="wordpress-${site}" 
    BACKUP_TARBALL_NAME=${site}-wordpress-files
    
    ARTEFACT=${BACKUP_TARBALL_NAME}.tgz
    ARTEFACT_NAME="/var/www/html tarball"

    SERVICE_NAME="${APPLICATION_NAME}_${WORDPRESS_HOST}"
    
    log_info "Creating ${ARTEFACT_NAME} from ${SERVICE_NAME} and saving it as $(pwd)/new_${ARTEFACT}"
    if /opt/sbdi/bin/service_exec -i $SERVICE_NAME tar cz /var/www/html > new_${ARTEFACT}
    then
	log_info "Sucessfully created ${ARTEFACT_NAME}"
	secure_and_save_artefact
    else
	log_warn "Failed to create ${ARTEFACT_NAME} - removing any partial results"
	success=false
	# remove artefact if any
	rm -rf  new_${ARTEFACT}
    fi
fi

if $success
then
    log_info "Backup successfull"
else
    log_fatal 97 "Failed to perform a complete backup"
fi


