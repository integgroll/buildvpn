#!/bin/bash
########################################################################################
# BuildVPN.sh | By: Mike Wright (@TheMightyShiv)
########################################################################################
#
# [Description]: Script to automate the installation and buildout of OpenVPN servers
#                and clients.
#
########################################################################################

# Global Variables
openvpn_dir='/etc/openvpn'
easyrsa_tmp='/usr/share/doc/openvpn/examples/easy-rsa/2.0'
easyrsa_dir='/etc/openvpn/easy-rsa'
ovpnkey_dir='/etc/openvpn/easy-rsa/keys'
ovpnsvr_cnf='/etc/openvpn/server.conf'

# Title Function
func_title(){

  # Clear (For Prettyness)
  clear

  # Print Title
  echo '=============================================================================='
  echo ' BuildVPN 1.1.0 | By: Mike Wright (@TheMightyShiv) | Updated: 11.2.2012'
  echo '=============================================================================='
  echo
}

# Server Install Function
func_install(){

  # Install Packages Through Apt-Get
  apt-get -y install openvpn openssl
  echo
}

# Server Buildout Function
func_build_server(){

  # Get User Input
  echo '[ Supported Operating Systems ]'
  echo
  echo ' 1 = Debian (5/6/7)'
  echo ' 2 = Ubuntu (12.04)'
  echo
  read -p 'Enter Operating System: ' os
  # Retry For People Who Don't Read Well
  if [ "${os}" != '1' ] && [ "${os}" != '2' ]
  then
    func_build_server
  fi
  read -p 'Enter Server Hostname...........................: ' host
  read -p 'Enter IP OpenVPN Will Bind To...................: ' ip
  read -p 'Enter Subnet For VPN (ex: 192.168.100.0)........: ' vpnnet
  read -p 'Enter Subnet Netmask (ex: 255.255.255.0)........: ' netmsk
  read -p 'Enter Preferred DNS Server (ex: 208.67.222.222).: ' dns
  read -p 'Enter Max Clients Threshold.....................: ' maxconn

  # Build Certificate Authority
  func_title
  echo '[*] Preparing Directories'
  cp -R ${easyrsa_tmp} ${easyrsa_dir}
  cd ${easyrsa_dir}
  # Workaround For Ubuntu
  if [ "${os}" == '2' ]
  then
    echo '[*] Preparing Ubuntu Config File'
    cp openssl-1.0.0.cnf openssl.cnf
  elif [ "${os}" != '1' ] && [ "${os}" != '2' ]
  then
    func_build_server
  fi
  echo '[*] Resetting Variables'
  . ./vars >> /dev/null
  echo '[*] Preparing Build Configurations'
  ./clean-all >> /dev/null
  echo '[*] Building Certificate Authority'
  ./build-ca
  func_title
  echo '[*] Building Key Server'
  ./build-key-server ${host}
  func_title
  echo '[*] Generating Diffie Hellman Key'
  ./build-dh
  func_title
  cd ${ovpnkey_dir}
  echo '[*] Generating TLS-Auth Key'
  openvpn --genkey --secret ta.key

  # Build Server Configuration
  echo "[*] Creating server.conf in ${openvpn_dir}"
  echo "local ${ip}" > ${ovpnsvr_cnf}
  echo 'port 1194' >> ${ovpnsvr_cnf}
  echo 'proto udp' >> ${ovpnsvr_cnf}
  echo 'dev tun' >> ${ovpnsvr_cnf}
  echo "ca ${ovpnkey_dir}/ca.crt" >> ${ovpnsvr_cnf}
  echo "cert ${ovpnkey_dir}/${host}.crt" >> ${ovpnsvr_cnf}
  echo "key ${ovpnkey_dir}/${host}.key" >> ${ovpnsvr_cnf}
  echo "dh ${ovpnkey_dir}/dh1024.pem" >> ${ovpnsvr_cnf}
  echo "server ${vpnnet} ${netmsk}" >> ${ovpnsvr_cnf}
  echo 'ifconfig-pool-persist ipp.txt' >> ${ovpnsvr_cnf}
  echo ';push "route 10.0.0.0 255.255.255.0"' >> ${ovpnsvr_cnf}
  echo ';push "redirect-gateway def1"' >> ${ovpnsvr_cnf}
  echo ";push "dhcp-option DNS ${dns}"" >> ${ovpnsvr_cnf}
  echo 'keepalive 10 120' >> ${ovpnsvr_cnf}
  echo "tls-auth ${ovpnkey_dir}/ta.key 0" >> ${ovpnsvr_cnf}
  echo 'comp-lzo' >> ${ovpnsvr_cnf}
  echo "max-clients ${maxconn}" >> ${ovpnsvr_cnf}
  echo 'user nobody' >> ${ovpnsvr_cnf}
  echo 'group nogroup' >> ${ovpnsvr_cnf}
  echo 'persist-key' >> ${ovpnsvr_cnf}
  echo 'persist-tun' >> ${ovpnsvr_cnf}
  echo 'status openvpn-status.log' >> ${ovpnsvr_cnf}
  echo ';log openvpn.log' >> ${ovpnsvr_cnf}
  echo 'verb 3' >> ${ovpnsvr_cnf}
  echo 'mute 20' >> ${ovpnsvr_cnf}

  # Finish Message
  echo '[*] Server Buildout Complete'
  echo
  exit 0
}

# Build Client Certificates Function
func_build_client(){

  # Get User Input
  read -p 'Enter Username (No Spaces)......................: ' user
  read -p 'Enter IP/Hostname OpenVPN Server Binds To.......: ' ip
  read -p 'Enter Node Name (Required For Windows Clients)..: ' node

  # Build Certificate
  func_title
  echo "[*] Generating Client Certificate For: ${user}"
  cd ${easyrsa_dir}
  ./build-key ${user}

  # Prepare Client Build Directory
  cd ${ovpnkey_dir}
  mkdir ${openvpn_dir}/${user}
  cp ca.crt ta.key ${user}.crt ${user}.key ${openvpn_dir}/${user}
  cd ${openvpn_dir}

  # Build Client Configuration
  func_title
  echo '[*] Creating Client Configuration'
  echo 'client' > ${user}/${user}.ovpn
  echo 'dev tun' >> ${user}/${user}.ovpn
  echo "dev-node ${node}" >> ${user}/${user}.ovpn
  echo 'proto udp' >> ${user}/${user}.ovpn
  echo "remote ${ip} 1194" >> ${user}/${user}.ovpn
  echo 'resolv-retry infinite' >> ${user}/${user}.ovpn
  echo 'nobind' >> ${user}/${user}.ovpn
  echo ';user nobody' >> ${user}/${user}.ovpn
  echo ';group nobody' >> ${user}/${user}.ovpn
  echo 'persist-key' >> ${user}/${user}.ovpn
  echo 'persist-tun' >> ${user}/${user}.ovpn
  echo 'mute-replay-warnings' >> ${user}/${user}.ovpn
  echo 'ca ca.crt' >> ${user}/${user}.ovpn
  echo "cert ${user}.crt" >> ${user}/${user}.ovpn
  echo "key ${user}.key" >> ${user}/${user}.ovpn
  echo 'ns-cert-type server' >> ${user}/${user}.ovpn
  echo 'tls-auth ta.key 1' >> ${user}/${user}.ovpn
  echo 'comp-lzo' >> ${user}/${user}.ovpn
  echo 'verb 3' >> ${user}/${user}.ovpn
  echo 'mute 20' >> ${user}/${user}.ovpn

  # Build Client Tarball
  echo "[*] Creating ${user}.tar Configuration Package In: ${openvpn_dir}"
  tar -cf ${user}.tar ${user}

  # Clean Up Temp Files
  echo '[*] Removing Temporary Files'
  rm -rf ${user}

  # Finish Message
  echo "[*] Client ${user} Buildout Complete"
  echo
  exit 0
}

func_title
if [ "${1}" == '-i' ] || [ "${1}" == '--install' ]
then
  func_install
elif [ "${1}" == '-s' ] || [ "${1}" == '--server' ]
then
  func_build_server
elif [ "${1}" == '-c' ] || [ "${1}" == '--client' ]
then
  func_build_client
else
  echo ' Usage...: ./BuildVPN.sh [OPTION]'
  echo ' Options.:'
  echo '           -i | --install = Install OpenVPN Packages'
  echo '           -s | --server  = Build Server Configuration'
  echo '           -c | --client  = Build Client Configuration'
  echo
  exit 1
fi
