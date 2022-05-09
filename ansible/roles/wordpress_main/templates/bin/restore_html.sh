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

WORDPRESS_HOST=wordpress-main # TODO: (maybe) get this from somewhere
BACKUP_TARBALL_NAME=var_www_html

export BACKUP_CTX=${DOCKER_CTX}/var/backup/${application_name}

[ ! -d ${BACKUP_CTX} ] && log_fatal 95 "No backup context found: ${BACKUP_CTX}" 

cd ${BACKUP_CTX}

if [ ! -z ${backup} ]
then
    [ ! -d ${backup} ] && log_fatal 96 "No backup found: ${BACKUP_CTX}/${backup}"
else
    cd ${backup}
    log_info "Selected backup ${backup}"
fi

[ ! -e ${BACKUP_TARBALL_NAME}.tgz ] &&  log_fatal 96 "${BACKUP_TARBALL_NAME}.tgz does not exist"

SERVICE_NAME="${application_name}_${WORDPRESS_HOST}"

log_info "Restoring /var/www/html from ${BACKUP_TARBALL_NAME}.tgz on ${SERVICE_NAME}"
#if /opt/sbdi/bin/service_exec -i $SERVICE_NAME rm -rf /var/www/html; tar xz -C / < ${BACKUP_TARBALL_NAME}.tgz
if /opt/sbdi/bin/service_exec -i $SERVICE_NAME tar xz -C / < ${BACKUP_TARBALL_NAME}.tgz
then
    log_info "Restored /var/www/html from ${BACKUP_TARBALL_NAME}.tgz on ${SERVICE_NAME}"
else
    log_fatal 1 "Failed to restore /var/www/html from ${BACKUP_TARBALL_NAME}.tgz on ${SERVICE_NAME}"
fi


