#! /bin/bash

cd $(dirname $0)
. log_utils

[[ $EUID -eq 0 ]] && log_fatal 88 "You are running as root - run as yourself..."

# Load and check configuration
# ============================

INSTALL_CONFIG=../etc/microstack.cfg

log_info "Reading configuration file ${INSTALL_CONFIG}"

[ ! -e ${INSTALL_CONFIG} ] && log_fatal 99 "Configuration file ${INSTALL_CONFIG} not found"

. ${INSTALL_CONFIG}

log_info "Checking configuration values and setting defaults"

[ -z "$ADMIN_PASSWORD" ] && log_fatal 90 "ADMIN_PASSWORD is not defined in ${INSTALL_CONFIG}"


: ${LOOP_DEVICE_FILE_SIZE:=50}
: ${OS_CLI_VENV_DIR:=".msclivenv"}
: ${OS_CLI_ENV_FILE_NAME:="mscli"}


: ${CLOUD_IMAGE_NAME:="ubuntu-20.40-server-cloudimg-amd64"}
: ${CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"}
: ${CLOUD_IMAGE_DOWNLOAD_DIR:=${HOME}/Downloads}



FLAVOR_NBR=0
for flavor in "${FLAVOR[@]}"   #${#FLAVOR[@]}
do
    #echo "Checking flavor (${flavor}) with nbr ${FLAVOR_NBR} i.e. ${FLAVOR[$FLAVOR_NBR]}"
    [ -z "${flavor}" ] &&  log_fatal 91 "Flavor number ${FLAVOR_NBR} in ${INSTALL_CONFIG} has no name"
    [ -z "${FLAVOR_CPU[$FLAVOR_NBR]}" ]  && log_fatal 91 "Number of CPUs not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
    [ -z "${FLAVOR_RAM[$FLAVOR_NBR]}" ]  && log_fatal 91 "RAM not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
    [ -z "${FLAVOR_DISK[$FLAVOR_NBR]}" ]  && log_fatal 91 "Disk size not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
    [ -z "${FLAVOR_EPHEMERAL[$FLAVOR_NBR]}" ]  && log_fatal 91 "Ephemeral disk size not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
    FLAVOR_NBR=$((FLAVOR_NBR+1))
done
    
log_info "Configuration seems valid - OK"

# Dependencies
# ============

log_info "Check that the user has an ssh public key"

if [ ! -e ${HOME}/.ssh/id_rsa.pub ]
then
    log_warn "Unable to find ${HOME}/.ssh/id_rsa.pub ... this setup assumes you have a private key"
else
    log_info "Found ${HOME}/.ssh/id_rsa.pub - ok"
fi

log_info "Install required ubuntu packages"

if sudo apt-get install -qq -y python3-dev python3-pip virtualenvwrapper build-essential wget snapd ca-certificates pass > /dev/null
then
    log_info "Required ubuntu packages installed - ok"
else
    log_fatal 92 "Unable to install required ubuntu packages"
fi

# Install and configure the snap
# ==============================

log_info "Check if MicroStack is already installed"

previous_installation=false

if snap list | grep -q microstack 
then
    log_warn "MicroStack is already installed"
    read -r -p "Do you want to remove and reinstall? [y/N] " response
    response=${response,,}    # tolower
    if [[ "$response" =~ ^(yes|y)$ ]]
    then
	log_info "Removing current MicroStack installation"
	if sudo snap remove --purge microstack
	then
	    log_info "Removed current MicroStack installation - OK"
	else
	    log_fatal 77 "Unable to remove current MicroStack installation... - giving up"
	fi
    else
	log_info "Keeping current MicorStack installation"
	previous_installation=true
    fi
else
    log_info "MicroStack is not installed - OK"
fi

if ! $previous_installation
then
    log_info "Try to install MicroStack beta in devmode"
    
    log_info "Esnuring net.ipv4.ip_forward=1"
    sudo sysctl net.ipv4.ip_forward=1
    
    installed_edge=false
    if  sudo snap install microstack --devmode --beta
    then
	log_info "Installed MicroStack beta in devmode - OK"
    else
	log_warn "Failed to install MicroStack beta in devmode..."
	# --devmode --beta (use edge since beta is not istalling today - jan 13th 2022)
	log_info "Will try to install MicroStack edge as a fallback"
	sudo snap remove --purge microstack
	if sudo snap install microstack --devmode --edge 
	then
	    installed_edge=true
	    log_info "Installed MicroStack edge - OK"
	else
	    log_fatal 93 "Failed to install MicroStack... - giving up"
	fi
    fi

    log_info "Setting MicroStack admin password"

    if sudo snap set microstack config.credentials.keystone-password=${ADMIN_PASSWORD}
    then
	log_info "MicroStack admin password set -ok"
    else
	log_warn "Failed to setting MicroStack admin password"
    fi


    
    log_info "Initializing MicroStack"

    if sudo microstack init --auto --control --setup-loop-based-cinder-lvm-backend --loop-device-file-size ${LOOP_DEVICE_FILE_SIZE}
    then
	log_info "MicroStack initialized - OK"
    else
	log_warn "MicroStack initialization failed for some reason"
    fi

    if $installed_edge
    then
	log_info "Fixing web interface bug in edge"
	sudo sed -i 's/DEBUG = False/DEBUG = True/g' /var/snap/microstack/common/etc/horizon/local_settings.d/_05_snap_tweaks.py
	sudo snap restart microstack.horizon-uwsgi
    fi
else
    read -r -p "Do you want to continue with the rest of the setup (i.e without reinstalling)? [y/N] " response
    response=${response,,}    # tolower
    if ! [[ "$response" =~ ^(yes|y)$ ]]
    then
	log_info "Exiting..."
	exit 0
    fi    
fi

log_info "Create an Openstack CLI Python venv"

if [ -e "${HOME}/${OS_CLI_VENV_DIR}" ]
then
    log_info "Found a previous Openstack CLI Python venv at ${HOME}/${OS_CLI_VENV_DIR} - removing this direcotry"
    rm -rf "${HOME}/${OS_CLI_VENV_DIR}" 
fi
 
virtualenv -p /usr/bin/python3 "${HOME}/${OS_CLI_VENV_DIR}" 
. ${HOME}/${OS_CLI_VENV_DIR}/bin/activate
pip3 install --upgrade pip
pip3 install python-openstackclient python-neutronclient
pip3 install ansible openstacksdk
pip3 install dnspython
ansible-galaxy collection install openstack.cloud
deactivate

log_info "Installed an  Openstack CLI Python venv at ${HOME}/${OS_CLI_VENV_DIR}"

log_info "Fixing MicroStak self signed CA cert issues"


# Microstack uses a self signed ca cert that will cause ssl access problem with ansible
# We fix that by adding the ca cert to our known and trusted ca certs:

MICROSTACK_SELF_SIGNED_CA=/var/snap/microstack/common/etc/ssl/certs/cacert.pem

if ! grep -q "ca.${HOSTNAME}.crt" /etc/ca-certificates.conf
then
    echo "ca.${HOSTNAME}.crt" | sudo tee -a /etc/ca-certificates.conf  > /dev/null
fi

sudo cp ${MICROSTACK_SELF_SIGNED_CA} /usr/share/ca-certificates/ca.${HOSTNAME}.crt
sudo update-ca-certificates --fresh

log_info "Fixing the Openstack CLI Python venv wrt this CA"

cat ${MICROSTACK_SELF_SIGNED_CA}  >> ${HOME}/${OS_CLI_VENV_DIR}/lib/python3.*/site-packages/certifi/cacert.pem


# Create OpenStack CLI env file
# =============================

log_info "Creating an OpenStack CLI env file"

# First get access data from MicroStack

openstack_accessable=false
while ! $openstack_accessable
do
    log_info "Trying to get the OS_AUTH_URL and OS_PROJECT_ID from the microstack.openstack command"
    OS_AUTH_URL=$(microstack.openstack endpoint list -f value | grep admin | grep '/v3/$' | grep -oE '[^ ]+$')
    OS_PROJECT_ID=$(microstack.openstack project show -f shell admin | grep "^id=" | cut -d'"' -f 2)
    if [ -z "$OS_AUTH_URL" ] || [ -z "$OS_PROJECT_ID" ]
    then
	log_warn "microstack.openstack command is not responding - waiting for it 5 seconds"
	sleep 5
    else
	openstack_accessable=true
    fi
done

# Decide where to put the CLI env file
# Preferrably in ${HOME}/bin else in ${HOME}/.bin if it exists or create ${HOME}/bin as a last resort


if [ -d ${HOME}/bin ]
then
   OS_CLI_ENV_FILE=${HOME}/bin/${OS_CLI_ENV_FILE_NAME} 
elif [ -d ${HOME}/.bin ]
then
    OS_CLI_ENV_FILE=${HOME}/.bin/${OS_CLI_ENV_FILE_NAME}
else
    OS_CLI_ENV_FILE=${HOME}/bin/${OS_CLI_ENV_FILE_NAME}
    
    if [ ! -d ${HOME}/bin ]
    then
	mkdir ${HOME}/bin 
    fi 
fi



cat <<EOF > ${OS_CLI_ENV_FILE}
#!/usr/bin/env bash

export OS_AUTH_URL=$OS_AUTH_URL
export OS_PROJECT_ID=$OS_PROJECT_ID
export OS_PROJECT_NAME="admin"
export OS_USER_DOMAIN_NAME="Default"
unset OS_PROJECT_DOMAIN_ID

# unset v2.0 items in case set
unset OS_TENANT_ID
unset OS_TENANT_NAME

export OS_USERNAME="admin"
export OS_PASSWORD=${ADMIN_PASSWORD}
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

pushd ~
if [ -d ${OS_CLI_VENV_DIR} ]
then
    . ${OS_CLI_VENV_DIR}/bin/activate
fi

if ! ssh-add -l &>/dev/null
then
   # We are running in a shell without ssh-agent
   eval \`ssh-agent -s\`
   ssh-add .ssh/id_rsa
fi

popd

openstack token issue

EOF


# Keep passwords a secret from other users
chmod 600 ${OS_CLI_ENV_FILE}

log_info "Openstack CLI env file created in ${OS_CLI_ENV_FILE}"

# Add SSH Key
# ==========

log_info "Ensure user ssh keys are added to microstack"

# Source the env file so that we get access to openstack commands
.  ${OS_CLI_ENV_FILE}

if ! openstack keypair list | grep -q "${USER}_key"
then
    if openstack keypair create --public-key ${HOME}/.ssh/id_rsa.pub ${USER}_key
    then
	log_info "Added ${HOME}/.ssh/id_rsa.pub to MicroStack as ${USER}_key - OK"
    else
	log_warn "Failed to add ${HOME}/.ssh/id_rsa.pub to MicroStack as ${USER}_key"
    fi
fi

# Add Flavors
# ===========

log_info "Ensure needed flavors are present in MicroStack"

FLAVOR_NBR=0
for flavor in "${FLAVOR[@]}"
do
    
    if ! openstack flavor list | grep -q ${flavor}
    then
	openstack flavor create  --vcpus ${FLAVOR_CPU[$FLAVOR_NBR]}  --ram ${FLAVOR_RAM[$FLAVOR_NBR]} --disk ${FLAVOR_DISK[$FLAVOR_NBR]} --ephemeral ${FLAVOR_EPHEMERAL[$FLAVOR_NBR]} ${flavor}
    fi
    FLAVOR_NBR=$((FLAVOR_NBR+1))
done

# Add Images
# ==========

log_info "Ensure needed images are present in MicroStack"

CLOUD_IMAGE_FILE=${CLOUD_IMAGE_URL##*/}

if ! openstack image list | grep -q "${CLOUD_IMAGE_NAME}"
then
    if [ ! -d "${CLOUD_IMAGE_DOWNLOAD_DIR}" ]
    then
	mkdir -p "${CLOUD_IMAGE_DOWNLOAD_DIR}"
    fi
    if [ -e "${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}" ]
    then
	log_info "Found ${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}"
	read -r -p "Do you want to download it again? [y/N] " response
	response=${response,,}    # tolower
	if [[ "$response" =~ ^(yes|y)$ ]]
	then
	    log_info "Downloading Cloud Image: ${CLOUD_IMAGE_URL}"
	    wget -P "${CLOUD_IMAGE_DOWNLOAD_DIR}" "${CLOUD_IMAGE_URL}"
	fi
    else
	log_info "Downloading Cloud Image: ${CLOUD_IMAGE_URL}"
	wget -P "${CLOUD_IMAGE_DOWNLOAD_DIR}" "${CLOUD_IMAGE_URL}"
    fi
    if openstack image create --min-ram 512 --min-disk 2 --file "${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}" --disk-format qcow2 "${CLOUD_IMAGE_NAME}"
    then
	log_info "Added Cloud Image: ${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE} as: ${CLOUD_IMAGE_NAME}"
    else
	log_warn "Failed to add Cloud Image: ${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE} as: ${CLOUD_IMAGE_NAME}"
    fi
fi

# Performace Tweeks
# =================


log_info "Tweeking sysctl for performace"

if ! grep -q -e "^[[:space:]]*fs.inotify.max_queued_events" /etc/sysctl.conf
then
    echo fs.inotify.max_queued_events=1048576 | sudo tee -a /etc/sysctl.conf
else
    sudo sed -i "/^[[:space:]]*fs.inotify.max_queued_events/c\fs.inotify.max_queued_events=1048576" /etc/sysctl.conf
fi

if ! grep -q -e "^[[:space:]]*fs.inotify.max_user_instances" /etc/sysctl.conf
then
    echo fs.inotify.max_user_instances=1048576 | sudo tee -a /etc/sysctl.conf
else
    sudo sed -i "/^[[:space:]]*fs.inotify.max_user_instances/c\fs.inotify.max_user_instances=1048576" /etc/sysctl.conf
fi

if ! grep -q -e "^[[:space:]]*fs.inotify.max_user_watches" /etc/sysctl.conf
then
    echo fs.inotify.max_user_watches=1048576 | sudo tee -a /etc/sysctl.conf
else
    sudo sed -i "/^[[:space:]]*fs.inotify.max_user_watches/c\fs.inotify.max_user_watches=1048576" /etc/sysctl.conf
fi

if ! grep -q -e "^[[:space:]]*vm.max_map_count" /etc/sysctl.conf
then
   echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf 
else
    sudo sed -i "/^[[:space:]]*vm.max_map_count/c\vm.max_map_count=262144" /etc/sysctl.conf
fi

if ! grep -q -e "^[[:space:]]*vm.swappiness" /etc/sysctl.conf
then
    echo vm.swappiness=1 | sudo tee -a /etc/sysctl.conf
else
    sudo sed -i "/^[[:space:]]/c\vm.swappiness=1" /etc/sysctl.conf
fi

if ! grep -q -e "^[[:space:]]*net.ipv4.ip_forward" /etc/sysctl.conf
then
    echo net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf
else
    sudo sed -i "/^[[:space:]]*net.ipv4.ip_forward/c\net.ipv4.ip_forward=1" /etc/sysctl.conf
fi

sudo sysctl -p


log_info "MicroStack is installed and configured - enjoy!"
log_info "Access the GUI at https://10.20.20.1"
log_info "To access MicroStack CLI (and run ansible playbooks etc..) issue the commmand: .  ${OS_CLI_ENV_FILE}"


# https://forum.snapcraft.io/t/snapd-not-installing-microstack/28280
# https://review.opendev.org/c/x/microstack/+/824276
