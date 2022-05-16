#! /bin/bash
cd $(dirname $0)
. /opt/sbdi/lib/log_utils

backup_db=true
backup_files=true
backup=""
while true 
do
    case $1 in
	-nodb)
	    backup_db=false
	    shift
	    ;;
	-nofiles)
	    backup_files=false
	    shift
	    ;;
	-to)
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
    main)  ;;
    tools) ;;
    docs)  ;;
    *) log_fatal 90 "site (${site} must be one of 'main', 'tools' or 'docs'" ;;
esac

log_info "Will attempt to backup site ${site}"

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
    if [ -e ${backup} ]
    then
	log_warn "Backup ${backup} already exists - will be backed up"
    fi
    NEW_BACKUP_DIR=`mktemp -d -p .`
    if chgrp docker ${NEW_BACKUP_DIR} && chmod 770 ${NEW_BACKUP_DIR}
    then
	if mv --backup=numbered -T ${NEW_BACKUP_DIR} ${backup}
	then
	    cd ${backup}
	else
	    rm -rf ${NEW_BACKUP_DIR}
	    log_fatal 96 "Unable to create backup directory: ${backup}, mv --backup=numbered -T ${NEW_BACKUP_DIR} ${backup}, error: $?"
	fi
    else
	rm -rf ${NEW_BACKUP_DIR}
	log_fatal 96 "Unable to create backup directory: ${backup}, chgrp docker ${NEW_BACKUP_DIR} && chmod 770 ${NEW_BACKUP_DIR}, error: $?"
    fi
    log_info "Using backup location: $(pwd)"
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


    ARTEFACT=${MYSQL_DATABASE}.sql
    ARTEFACT_NAME="database dump"

    SERVICE_NAME="${application_name}_${MYSQL_HOST}"
#    SERVICE_NAME="${application_name%_*}_${MYSQL_HOST}"

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
    BACKUP_TARBALL_NAME=${site}_var_www_html
    
    ARTEFACT=${BACKUP_TARBALL_NAME}.tgz
    ARTEFACT_NAME="/var/www/html tarball"

    SERVICE_NAME="${application_name}_${WORDPRESS_HOST}"
    #    SERVICE_NAME="${application_name%_*}_${WORDPRESS_HOST}"
    
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


