#! /bin/bash

bin_dir=$(dirname $0)
lib_dir=/opt/sbdi/lib  #${SOMO_LIBDIR:-$bin_dir/../lib}

. $lib_dir/log_utils

log_logging_application="NAGIOS_SERVER_INSTALL"

log_info "Installing Nagios server"

[ $EUID -eq 0 ] || log_fatal 88 "Root privileges reqiured to install Nagios Server"

# Read arguments and switches
verbose=""           # -v 
dry_run=""           # -t 
nagios_admin_pw=""   # -p
apache_port=""       # -port
while true 
do
    case $1 in
	-v) verbose="-v"
	    shift
	    ;;
	-t) dry_run="-t"
	    shift
	    ;;
	-p) nagios_admin_pw=$2
	    shift
	    shift
	    ;;
	-port) apache_port=$2
	    shift
	    shift
	    ;;
	*) break	    
	   ;;
    esac
done


#if RUNLEVEL=1 apt-get --reinstall install apache2 
if apt-get --reinstall install apache2 
then
    log_info "Installed apache2 - OK"
else
    log_fatal 91 "Unable to install apache  - Unable to proceed!"
fi   
    
if [ ! -z "${apache_port}" ]
then
    log_info "Configuring apache to listen to port ${apache_port}"
    systemctl stop apache2
    sed -i "s#^Listen .*#Listen ${apache_port}#" /etc/apache2/ports.conf
    sed -i "s#<VirtualHost.*\*:.*>#<VirtualHost \*:${apache_port}>#" /etc/apache2/sites-enabled/000-default.conf
    if systemctl restart apache2
    then
	log_info "Restarted apache after configuring server port: ${apache_port}"
    else
	log_fatal 91 "Unable to restart apache after configuring server port: ${apache_port}"
    fi
else
    log_info "Not changing apache server port"
    systemctl restart apache2
fi


if apt-get install autoconf bc gawk dc build-essential gcc libc6 make wget unzip php libapache2-mod-php libgd-dev libmcrypt-dev make libssl-dev snmp libnet-snmp-perl gettext -y
then
    log_info "Installed dependencies - OK"
else
     log_fatal 91 "Unable to install dependencies  - Unable to proceed!"
fi

cd /tmp
if [ -e nagiosserver ]
then
    rm -rf nagiosserver
fi
mkdir nagiosserver
cd nagiosserver
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
MD5SUM=$(md5sum nagios-4.4.6.tar.gz)
# Check md5sum:
if [ "$MD5SUM" == "ba849e9487e13859381eb117127bfee2  nagios-4.4.6.tar.gz" ]
then
    log_info "Downloaded Nagios source MD5 with correct checksum checksum - OK"
else
    log_fatal 92 "Nagios source MD5 checksum does not validate  - Unable to proceed! "
fi

tar -xvzf nagios-4.4.6.tar.gz
cd nagios-4.4.6
if ./configure --with-httpd-conf=/etc/apache2/sites-enabled
then
    log_info "Configured Nagios server build"
else
    log_fatal 92 "Unable to configure Nagios server build - Unable to proceed! "
fi

make all
make install-groups-users
usermod -a -G nagios www-data
make install
make install-daemoninit
make install-commandmode
make install-config
make install-webconf
# make install-exfoliation

# Old cgi style:
# sudo a2dismod mpm_event
# sudo a2enmod mpm_prefork
# sudo service apache2 restart
# sudo a2enmod rewrite cgi

# New cgid style:
a2enmod rewrite cgid

systemctl restart apache2

htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin ${nagios_admin_pw:-"nagiosadmin"}

apt-get install monitoring-plugins nagios-nrpe-plugin -y
mkdir -p /usr/local/nagios/etc/servers
chown nagios. /usr/local/nagios/etc/servers
sed -i 's#.*cfg_dir=/usr/local/nagios/etc/servers.*#cfg_dir=/usr/local/nagios/etc/servers#' /usr/local/nagios/etc/nagios.cfg
sed -i 's#.*\$USER1\$.*#\$USER1\$=/usr/lib/nagios/plugins#' /usr/local/nagios/etc/resource.cfg
sed -i 's/nagios@localhost/hans.hook@nrm.se/' /usr/local/nagios/etc/objects/contacts.cfg
cat << EOF >> /usr/local/nagios/etc/objects/commands.cfg 

define command{
        command_name check_nrpe
        command_line \$USER1\$/check_nrpe -H \$HOSTADDRESS\$ -c \$ARG1\$
}
EOF

if /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
then
    log_info "Nagios configuration validated - OK"
else
    log_fatal 92 "Nagios configuration is not valid - Unable to proceed!"
fi

systemctl start nagios
systemctl enable nagios

systemctl restart apache2


# Clean up:
#sudo apt-get purge lib*-dev
# TODO: remove leftovers

log_info "Nagios server installed"
