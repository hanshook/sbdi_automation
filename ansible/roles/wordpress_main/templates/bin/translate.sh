#! /bin/bash
cd $(dirname $0)
. /opt/sbdi/lib/log_utils

translate_from=""
translate_to=""
translate_db=true
translate_files=true
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
	-nodb)
	    translate_db=false
	    shift
	    ;;
	-nofiles)
	    translate_files=false
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

log_info "Will attempt to translate site ${site}"

success=true

WORDPRESS_HOST="wordpress-${site}" 
SERVICE_NAME="${application_name}_${WORDPRESS_HOST}"

if ! $translate_db
then
    log_info "Skipping db translation"
else
    # Translate database
    # ==================

    if  ! /opt/sbdi/bin/service_exec -i $SERVICE_NAME "[ -e wp-cli.phar ]"
    then
	wp_cli_exists=false
	log_warn "No wp-cli found on wp host - will attempt install"
	curl  --output - https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar | /opt/sbdi/bin/service_exec -i $SERVICE_NAME sed -n \'w /var/www/html/wp-cli.phar\'       
	/opt/sbdi/bin/service_exec -i $SERVICE_NAME "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
	/opt/sbdi/bin/service_exec -i $SERVICE_NAME "chmod +x wp-cli.phar"
	if  /opt/sbdi/bin/service_exec -i $SERVICE_NAME "[ -e wp-cli.phar ]"
	then
	    wp_cli_exists=true
	    log_info "Installed wp-cli"
	else
	    success=false
	    log_error "Failed to install wp-cli"
	fi
    fi
    if $wp_cli_exists
    then
	log_info "Performing db translation"

	if /opt/sbdi/bin/service_exec -i $SERVICE_NAME "php wp-cli.phar search-replace \"${translate_from}\" \"${translate_to}\" --allow-root  --all-tables"
	then
	    log_info "Translated db"
	else
	    success=false
	    log_error "Failed to translate db"
	fi
    fi
fi


if ! $translate_files
then
    log_info "Skipping files translation"
else
    # Translate files in /var/www/html
    # ================================
    
    log_info "Performing file translations"
    files_to_translate=$(/opt/sbdi/bin/service_exec -i $SERVICE_NAME "grep -r -e \"${translate_from}\""  | cut -d: -f1 | sort -d | uniq | xargs)
    if [ $? -ne 0 ]
    then
	success=false
	log_error "Failed to determine what files to translate"
    else
	for file_to_translate in ${files_to_translate};
	do
	    if /opt/sbdi/bin/service_exec -i $SERVICE_NAME "sed -i \"s,${translate_from},${translate_to},g\" ${file_to_translate}"
	    then
		log_info "Translated ${file_to_translate}"
	    else
		success=false
		log_error "Failed to translate ${file_to_translate}"
	    fi	
	done
    fi
    log_info "Done performing file translations"
fi

if $success
then
    log_info "Translation successfull"
else
    log_fatal 97 "Failed to perform a complete translation"
fi


