#! /bin/bash
cd $(dirname $0)
. /opt/sbdi/lib/log_utils

translate_from=""
translate_to=""
while true 
do
    case $1 in
	-from)
	    translate_from=$2
	    shift
	    shift
	    ;;
	-to)
	    translate_to=$2
	    shift
	    shift
	    ;;
	*) break	    
	   ;;
    esac
done

[ -z "${translate_from}" ] && log_fatal 90 "-from not provided" 
[ -z "${translate_to}" ] && log_fatal 90 "-to not provided"

translation_name=${3:-"${translate_from}_${translate_to}"}

[ $EUID -eq 0 ] && log_fatal 88 "Do *not* run as root"
if ! id -nG "$USER" | grep -qw "docker"
then
    log_fatal 88 "User must belong to group 'docker'"
fi
if ! sudo -v &> /dev/null
then
   log_fatal 88 "Sudoers rights is required"
fi

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

export DOCKER_CTX={{ docker_ctx | default('/docker') }}

env_file="${DOCKER_CTX}/etc/${application_name}/env/.env${application_name}"

[ ! -e "${env_file}" ] && log_fatal 91 "env file does not exist: ${env_file}" 

export $(grep -v '^#' ${env_file} | xargs)

MYSQL_DATABASE=${WORDPRESS_DB_NAME}

[ -z "$MYSQL_DATABASE" ] &&  log_fatal 93 "MYSQL_DATABASE not in env file" 

BACKUP_TARBALL_NAME=var_www_html

export BACKUP_CTX=${DOCKER_CTX}/var/backup/${application_name}

[ ! -d ${BACKUP_CTX} ] && log_fatal 95 "No backup context found: ${BACKUP_CTX}" 

cd ${BACKUP_CTX}

[ ! -e "${MYSQL_DATABASE}.sql" ] &&  log_fatal 96 "${MYSQL_DATABASE}.sql does not exist"
[ ! -e ${BACKUP_TARBALL_NAME}.tgz ] &&  log_fatal 96 "${BACKUP_TARBALL_NAME}.tgz does not exist"

if [ -e ${translation_name} ]
then
    log_warn "Transaltion ${translation_name} already exist "
    if ! mv -b ${translation_name} ${translation_name}.backup
    then
	log_fatal 97 "Unable to backup ${translation_name} directory"
    fi
fi
if ! mkdir ${translation_name}
then
    log_fatal 97 "Unable to create ${translation_name} directory"
else
    log_info "Created new translated backup ${translation_name}"
fi
if ! chown $USER.docker ${translation_name}
then
    log_fatal 97 "Unable to set proper owner rights on ${translation_name} directory"
fi


cd  ${translation_name}
if cp ${BACKUP_CTX}/${MYSQL_DATABASE}.sql .
then
    log_info "Copied ${MYSQL_DATABASE}.sql to $(pwd)"
else
    log_fatal 97 "Unable to copy ${MYSQL_DATABASE}.sql to $(pwd)"
fi

mkdir files
cd files
if sudo tar xzf ${BACKUP_CTX}/${BACKUP_TARBALL_NAME}.tgz
then
    log_info "Unpacked ${BACKUP_TARBALL_NAME}.tgz in $(pwd)"
else
    log_fatal 97 "Unable to unpack ${BACKUP_TARBALL_NAME}.tgz"
fi

cd ..

log_info "Replacing all \"${translate_from}\" with \"${translate_to}\" in backup ${translation_name}"

files_to_translate=$(sudo grep -r -e "${translate_from}" * | cut -d: -f1 | sort -d | uniq | xargs)

for file_to_translate in ${files_to_translate};
do
    log_info "Translating ${file_to_translate}"
    sudo sed -i "s,${translate_from},${translate_to},g" ${file_to_translate}
done

cd files
if sudo tar czf ../${BACKUP_TARBALL_NAME}.tgz var/www/html
then
    log_info "Packaged translated html files as ${BACKUP_CTX}/${translation_name}/${BACKUP_TARBALL_NAME}.tgz"
else
    log_warn "Unable to package translated html files as ${BACKUP_CTX}/${translation_name}/${BACKUP_TARBALL_NAME}.tgz"
fi
cd ..
if sudo rm -rf files
then
    log_info "Cleaned up working files"
else
    log_warn "Unable to clean up working files.."
fi
if sudo chown $USER.docker *
then
    log_info "Secure ownership is now set on translated backup"
else	     
    log_warn "Failed to set secure ownership of translated backup"
fi
if chmod 660 *
then
    log_info "Secure access rights is now set on translated backup"
else
    log_warn "Failed to set secure access rights of translated backup"
fi




