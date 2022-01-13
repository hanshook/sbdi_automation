#! /bin/bash

if [[ $EUID -eq 0 ]]
then
    >&2 echo "You are running as root - run as yourself..."
    exit 88
fi

cd $(dirname $0)
. log_utils

INSTALL_CONFIG=../etc/microstack.cfg

[ ! -e ${INSTALL_CONFIG} ] && log_fatal 99 "Configuration file ${INSTALL_CONFIG} not found"


# Read configuration file
# -----------------------

. ${INSTALL_CONFIG}

# Check values from configuration file and set defaults
# -----------------------------------------------------

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
    

log_info "Check that the user has an ssh public key"

if [ ! -e ${HOME}/.ssh/id_rsa.pub ]
then
    log_warn "Unable to find ${HOME}/.ssh/id_rsa.pub ... this setup assumes you have a private key"
else
    log_info "Found ${HOME}/.ssh/id_rsa.pub - ok"
fi

log_info "Install the ubuntu packages we need"

sudo apt-get install -qq -y python3-dev python3-pip virtualenvwrapper build-essential wget snapd ca-certificates pass > /dev/null


log_info "Check if MicroStack is already installed"

if snap list | grep -q microstack 
then
    # 
    echo "MicroStack is already installed"
    echo "If you desire a clean install removit it with:"
    echo "sudo snap remove --purge microstack"
    echo "and rerun this script."
    exit 1
else
    log_info "MicroStack is not installed - OK"
fi

log_info "Try to install MicroStack beta in devmode"

if  sudo snap install microstack --devmode --beta
then
    log_info "Installed MicroStack beta in devmode"
else
    log_warn "Failed to install MicroStack beta in devmode..."
    # --devmode --beta (use edge since beta is not istalling today - jan 13th 2022)
    log_info "Will try to install microstack edge as a fallback"
    sudo snap remove --purge microstack
    if sudo snap install microstack --edge
    then
	log_info "Installed MicroStack edge - OK"
    else
	log_fatal 93 "Failed to install MicroStack... - giving up"
    fi
fi

log_info "Setting MicroStack admin password"

if ! sudo snap set microstack config.credentials.keystone-password=${ADMIN_PASSWORD}
then
    log_warn "Failed to setting MicroStack admin password"
fi

log_info "Initializing MicroStack"

if ! sudo microstack init --auto --control --setup-loop-based-cinder-lvm-backend --loop-device-file-size ${LOOP_DEVICE_FILE_SIZE}
then
    log_warn "MicroStack initialization failed for some reason"
fi

log_info "Create an Openstack CLI Python venv"

if [ -e "${HOME}/${OS_CLI_VENV_DIR}" ]
then
    log_info "Found a previous Openstack CLI Python venv at ${HOME}/${OS_CLI_VENV_DIR} - removing this direcotry"
    rm -rf "${HOME}/${OS_CLI_VENV_DIR}" 
fi
 
virtualenv "${HOME}/${OS_CLI_VENV_DIR}" 
. ${HOME}/${OS_CLI_VENV_DIR}/bin/activate
pip3 install --upgrade pip
pip3 install python-openstackclient python-neutronclient
pip3 install ansible openstacksdk
ansible-galaxy collection install openstack.cloud
deactivate

log_info "Installed an  Openstack CLI Python venv at ${HOME}/${OS_CLI_VENV_DIR}"

log_info "Fix MicroStak self signed ca cert issues"


# Microstack uses a self signed ca cert that will cause ssl access problem with ansible
# We fix that by adding the ca cert to our known and trusted ca certs:

MICROSTACK_SELF_SIGNED_CA=/var/snap/microstack/common/etc/ssl/certs/cacert.pem

if ! grep -q "ca.${HOSTNAME}.crt" /etc/ca-certificates.conf
then
    echo "ca.${HOSTNAME}.crt" | sudo tee -a /etc/ca-certificates.conf  > /dev/null
fi

sudo cp ${MICROSTACK_SELF_SIGNED_CA} /usr/share/ca-certificates/ca.${HOSTNAME}.crt
sudo update-ca-certificates --fresh

log_info "Also fix the Openstack CLI Python venv wrt this CA"

cat ${MICROSTACK_SELF_SIGNED_CA}  >> ${HOME}/${OS_CLI_VENV_DIR}/lib/python3.*/site-packages/certifi/cacert.pem

log_info "Create an Openstack CLI env file"

# Preferably in ${HOME}/bin else in ${HOME}/.bin if it exists or create ${HOME}/bin as a last resort

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

export OS_AUTH_URL=$(microstack.openstack endpoint list -f value | grep admin | grep '/v3/$' | grep -oE '[^ ]+$')
export OS_PROJECT_ID=$(microstack.openstack project show -f shell admin | grep "^id=" | cut -d'"' -f 2)
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
   eval `ssh-agent -s`
   ssh-add .ssh/id_rsa
fi

popd

openstack token issue

EOF


# Keep passwords a secret from other users
chmod 600 ${OS_CLI_ENV_FILE}

log_info "Openstack CLI env file created in ${OS_CLI_ENV_FILE}"
log_info "To access MicroStack CLI (and run ansible playbooks etc..) issue the commmand: .  ${OS_CLI_ENV_FILE}"


log_info "Ensure user ssh keys are added to microstack"

# Source the env file so that we get access to openstack commands
.  ${OS_CLI_ENV_FILE}

if ! openstack keypair list | grep -q "${USER}_key"
then
    openstack keypair create --public-key ${HOME}/.ssh/id_rsa.pub ${USER}_key
fi

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

log_info "Ensure needed images are present in MicroStack"

CLOUD_IMAGE_FILE=${CLOUD_IMAGE_URL##*/}

if ! openstack image list | grep -q "${CLOUD_IMAGE_NAME}"
then
    if [ ! -d "${CLOUD_IMAGE_DOWNLOAD_DIR}" ]
    then
	mkdir -p "${CLOUD_IMAGE_DOWNLOAD_DIR}"
    fi
    if [ ! -e "${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}" ]
    then
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

# https://forum.snapcraft.io/t/snapd-not-installing-microstack/28280
# https://review.opendev.org/c/x/microstack/+/824276
# https://kubesphere.com.cn/en/docs/reference/storage-system-installation/glusterfs-server/
