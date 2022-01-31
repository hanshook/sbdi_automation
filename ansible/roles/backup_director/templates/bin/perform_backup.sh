#! /bin/bash

bin_dir=$(dirname $0)
lib_dir=/opt/sbdi/lib  #${SOMO_LIBDIR:-$bin_dir/../lib}

. $lib_dir/log_utils

# TODO: Use parallell ssh to perform taking all snapshots at same time.

{% for host in groups['backup_sources'] %}

go_on=true

log_info "Backing up {{ host }}"

# Prepare source snapshot
# -----------------------

if ssh {{deployment_prefix}}-{{ host }} 'sudo /opt/sbdi/backup/bin/prepare_source_snapshot'
then
    log_info "Successfully prepared source snapshot for {{ host }}"
else
    error_code=$?
    log_error "Failed to prepared source snapshot for {{ host }} - error: ${error_code}"
    go_on=false
fi

if $go_on
then

    # Rsync source snapshot -> backup target
    # --------------------------------------

    # Authorized SSH key is kept only on backup-director
    
    # Start ssh agent (needed for ssh -A) and load the key:

    eval `ssh-agent -s`
    ssh-add .ssh/id_rsa

    
    # Use ssh -A to bring it along
    
    if ssh -A {{deployment_prefix}}-{{ host }} 'sudo /opt/sbdi/backup/bin/perform_rsync'
    then
	log_info "Successfully backed up source snapshot for {{ host }}"
    else
	error_code=$?
	log_error "Failed to sync source snapshot for {{ host }} - error: ${error_code}"
	go_on=false
    fi
fi
if $go_on
then

    # Remove source snapshot
    # ----------------------
    
    if ssh {{deployment_prefix}}-{{ host }} 'sudo /opt/sbdi/backup/bin/remove_source_snapshot'
    then
	log_info "Successfully removed source snapshot for {{ host }}"
    else
	error_code=$?
	log_error "Failed to remove source snapshot for {{ host }} - error: ${error_code}"
    fi
fi

{% endfor %}




