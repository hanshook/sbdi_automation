#! /bin/bash

if [[ $EUID -eq 0 ]]
then
    >&2 echo "You may be root - run as yourself..."
    exit 88
fi

cd $(dirname $0)

INSTALL_CONFIG=../etc/microstack.cfg
if [ ! -e ${INSTALL_CONFIG} ]
then
    >&2 echo "Configuration file ${INSTALL_CONFIG} not found"
    exit 99
fi

# Read configuration file
# -----------------------

. ${INSTALL_CONFIG}

# Check values from configuration file and set defaults
# -----------------------------------------------------

if [ -z "$ADMIN_PASSWORD" ]
then
    >&2 echo "ADMIN_PASSWORD is not defined in ${INSTALL_CONFIG}"
    exit 90
fi

: ${LOOP_DEVICE_FILE_SIZE:=50}
: ${OS_CLI_VENV_DIR:=".msclivenv"}
: ${OS_CLI_ENV_FILE_NAME:="mscli"}


: ${CLOUD_IMAGE_NAME:="ubuntu-20.40-server-cloudimg-amd64"}
: ${CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-disk-kvm.img"}
: ${CLOUD_IMAGE_DOWNLOAD_DIR:=${HOME}/Downloads}



FLAVOR_NBR=0
for flavor in "${FLAVOR[@]}"   #${#FLAVOR[@]}
do
    #echo "Checking flavor (${flavor}) with nbr ${FLAVOR_NBR} i.e. ${FLAVOR[$FLAVOR_NBR]}"
    if [ -z "${flavor}" ]
    then
	>&2 echo "Flavor number ${FLAVOR_NBR} in ${INSTALL_CONFIG} has no name"
	exit 91
    fi
    if [ -z "${FLAVOR_CPU[$FLAVOR_NBR]}" ]
    then
	>&2 echo "Number of CPUs not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
	exit 91
    fi
    if [ -z "${FLAVOR_RAM[$FLAVOR_NBR]}" ]
    then
	>&2 echo "RAM not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
	exit 91
    fi
    if [ -z "${FLAVOR_DISK[$FLAVOR_NBR]}" ]
    then
	>&2 echo "Disk size not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
	exit 91
    fi
    if [ -z "${FLAVOR_EPHEMERAL[$FLAVOR_NBR]}" ]
    then
	>&2 echo "Ephemeral disk size not defined for flavour ${flavour} in ${INSTALL_CONFIG}"
	exit 91
    fi
    FLAVOR_NBR=$((FLAVOR_NBR+1))
done
    

# Check that the user has an ssh public key
# -----------------------------------------

if [ ! -e ${HOME}/.ssh/id_rsa.pub ]
then
    >&2 echo "Unable to find ${HOME}/.ssh/id_rsa.pub ... this setup assumes you have a private key"
fi

# Install the ubuntu packages we need
# -----------------------------------

sudo apt-get install -qq -y python3-dev python3-pip virtualenvwrapper build-essential wget snapd ca-certificates > /dev/null


# Check if Microstack is already installed
# ----------------------------------------

if snap list | grep -q microstack 
then
    # 
    echo "Microstack is already installed"
    echo "If you desire a clean install removit it with:"
    echo "sudo snap remove --purge microstack"
    echo "and rerun this script."
    exit 1
fi

# Install microstack for development use
# --------------------------------------

sudo snap install microstack --devmode --beta

# Set admin password
# ------------------
sudo snap set microstack config.credentials.keystone-password=${ADMIN_PASSWORD}

# Iitialize microstack
# --------------------

sudo microstack init --auto --control --setup-loop-based-cinder-lvm-backend --loop-device-file-size ${LOOP_DEVICE_FILE_SIZE}


# Create an Openstack CLI Python venv
# -----------------------------------

if [ -e "${HOME}/${OS_CLI_VENV_DIR}" ]
then
    rm -rf "${HOME}/${OS_CLI_VENV_DIR}" 
fi

virtualenv "${HOME}/${OS_CLI_VENV_DIR}" 
. ${HOME}/${OS_CLI_VENV_DIR}/bin/activate
pip3 install --upgrade pip
pip3 install python-openstackclient python-neutronclient
pip3 install ansible openstacksdk
ansible-galaxy collection install openstack.cloud
deactivate

# Fix Micorstak self signed ca cert issues
# ----------------------------------------

# Microstack uses a self signed ca cert that will cause ssl access problem with ansible
# We fix that by adding the ca cert to our known and trusted ca certs:

MICROSTACK_SELF_SIGNED_CA=/var/snap/microstack/common/etc/ssl/certs/cacert.pem

if ! grep -q "ca.${HOSTNAME}.crt" /etc/ca-certificates.conf
then
    echo "ca.${HOSTNAME}.crt" | sudo tee -a /etc/ca-certificates.conf  > /dev/null
fi

sudo cp ${MICROSTACK_SELF_SIGNED_CA} /usr/share/ca-certificates/ca.${HOSTNAME}.crt
sudo update-ca-certificates --fresh

# Also fix the Openstack CLI Python venv wrt this CA:

cat ${MICROSTACK_SELF_SIGNED_CA}  >> ${HOME}/${OS_CLI_VENV_DIR}/lib/python3.*/site-packages/certifi/cacert.pem

# Create an Openstack CLI env file
# ---------------------------------

# Preferably in ${HOME}/.bin else in ${HOME}/bin


if [ -d ${HOME}/.bin ]
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

if ! ps -p $SSH_AGENT_PID > /dev/null
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

# Source the env file so that we get access to openstack commands
# ---------------------------------------------------------------

.  ${OS_CLI_ENV_FILE}



# Ensure user ssh keys are added to microstack
# --------------------------------------------

if ! openstack keypair list | grep -q "${USER}_key"
then
    openstack keypair create --public-key ${HOME}/.ssh/id_rsa.pub ${USER}_key
fi

# Ensure needed flavors are present in microstack
# -----------------------------------------------

FLAVOR_NBR=0
for flavor in "${FLAVOR[@]}"
do
    
    if ! openstack flavor list | grep -q ${flavor}
    then
	openstack flavor create  --vcpus ${FLAVOR_CPU[$FLAVOR_NBR]}  --ram ${FLAVOR_RAM[$FLAVOR_NBR]} --disk ${FLAVOR_DISK[$FLAVOR_NBR]} --ephemeral ${FLAVOR_EPHEMERAL[$FLAVOR_NBR]} ${flavor}
    fi
    FLAVOR_NBR=$((FLAVOR_NBR+1))
done

# Ensure needed images are present in microstack
# ----------------------------------------------

CLOUD_IMAGE_FILE=${CLOUD_IMAGE_URL##*/}

if ! openstack image list | grep -q "${CLOUD_IMAGE_NAME}"
then
    if [ ! -d "${CLOUD_IMAGE_DOWNLOAD_DIR}" ]
    then
	mkdir -p "${CLOUD_IMAGE_DOWNLOAD_DIR}"
    fi
    if [ ! -e "${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}" ]
    then
	wget -P "${CLOUD_IMAGE_DOWNLOAD_DIR}" "${CLOUD_IMAGE_URL}"
    fi
    openstack image create --min-ram 512 --min-disk 2 --file "${CLOUD_IMAGE_DOWNLOAD_DIR}/${CLOUD_IMAGE_FILE}" --disk-format qcow2 "${CLOUD_IMAGE_NAME}"
fi
