#!/bin/sh
#

VPN_SERVER_IP='{{snic_vpn_server_ip}}'
VPN_IPSEC_PSK='{{ipsec_psk}}'
VPN_USER='{{ip_sec_users[0].key}}'
VPN_PASSWORD='{{ip_sec_users[0].value.ipsec_password}}'



cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

conn myvpn
  auto=add
  keyexchange=ikev1
  authby=secret
  type=transport
  left=%defaultroute
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
  ike=aes128-sha1-modp2048
  esp=aes128-sha1
EOF
#  left=%defaultroute
#  left=89.45.234.37
#  leftsourceip=192.168.1.3
#  leftsourceip=89.45.234.37

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
debug network = yes
debug state = yes
debug tunnel = yes
debug avp = yes
[lac myvpn]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes

EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name "$VPN_USER"
password "$VPN_PASSWORD"
EOF


#mtu 1280
#mru 1280

chmod 600 /etc/ppp/options.l2tpd.client

