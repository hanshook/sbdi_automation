# IPsec server setup


[IPsec VPN Server Auto Setup Scripts at github](https://github.com/hwdsl2/setup-ipsec-vpn)

[Howto on seting up server whith these scripts](https://www.tecmint.com/create-own-ipsec-vpn-server-in-linux/)
[Howto on seting up client whith these scripts](https://www.tecmint.com/setup-l2tp-ipsec-vpn-client-in-linux/)

Psec VPN server is now ready for use!

Connect to your new VPN with these details:

Server IP: 130.238.28.173
IPsec PSK: 
Username: hans
Password: 

Write these down. You'll need them to connect!

Important notes:   https://git.io/vpnnotes
Setup VPN clients: https://git.io/vpnclients
IKEv2 guide:       https://git.io/ikev2

================================================

================================================

IKEv2 setup successful. Details for IKEv2 mode:

VPN server address: 130.238.28.173
VPN client name: vpnclient

Client configuration is available at:
/home/hans/vpnclient.p12 (for Windows & Linux)
/home/hans/vpnclient.sswan (for Android)
/home/hans/vpnclient.mobileconfig (for iOS & macOS)

Note: No password is required when importing
client configuration.

Next steps: Configure IKEv2 VPN clients. See:
https://git.io/ikev2clients

================================================
