#!/bin/bash
set -euo pipefail
# set -ex # for debug
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

DOCKER_VERSION=18.09.3
COMPOSE_VERSION=1.25.3

sudo apt update
sudo apt install -y curl

get_script_dir () {
     SOURCE="${BASH_SOURCE[0]}"
     # While $SOURCE is a symlink, resolve it
     while [ -h "$SOURCE" ]; do
          DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
          SOURCE="$( readlink "$SOURCE" )"
          # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
          [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     done
     DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     echo "$DIR"
}

BASEDIR=$(get_script_dir)

if [ -f "/usr/bin/docker" ] && [ -f "/usr/local/bin/docker-compose" ]; then
    echo "[*] Already install docker!"
else
    rm -rf $BASEDIR/envimage/
    echo "[*] Download docker"
    wget https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz -P "$BASEDIR/envimage/"
    echo "[*] Download docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-Linux-x86_64" -o $BASEDIR/envimage/docker-compose
    echo "[*] Install docker & docker-compose"
    source $BASEDIR/install_docker.sh
fi

echo "[*] Build & Pull docker images"
find $BASEDIR -type f -name "docker-compose.yml" -exec docker-compose -f {} --log-level ERROR build \;
find $BASEDIR -type f -name "docker-compose.yml" -exec docker-compose -f {} --log-level ERROR pull \;

sudo mv /etc/sysctl.conf.bak /etc/sysctl.conf 2>/dev/null || true
sudo cp -n /etc/sysctl.conf{,.bak}

sudo sh -c "echo 'vm.max_map_count=262144
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216

net.ipv4.tcp_max_syn_backlog = 8096
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.udp_mem = 4096 12582912 16777216
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.ip_local_port_range = 10240 65535' >> /etc/sysctl.conf"
sudo sysctl -p

sudo mv /etc/security/limits.conf.bak /etc/security/limits.conf 2>/dev/null || true
sudo cp -n /etc/security/limits.conf{,.bak}
sudo sh -c "echo 'root soft nofile 655360
root hard nofile 655360
* soft nofile 655360
* hard nofile 655360' >> /etc/security/limits.conf"

find $BASEDIR -maxdepth 1 -mindepth 1 -type d -exec ln -s ../SecBuzzerESM.env {}/.env \; 2>/dev/null || true

#API_KEY=`cat $BASEDIR/SecBuzzerESM.env | grep API_KEY_VALUE | cut -d = -f 2`
#if [ -n "$API_KEY" ]
#then
#mkdir -p tmp/rules
#current_rules_version=`curl -X POST "https://api.esm.secbuzzer.co/esmapi/web/file/fileVersion" -d "{'TypeCode': 'it'}" -H "Content-Type: application/json" -H "accept: */*" -H "authorization: $API_KEY" | cut -d : -f 2 | cut -d \" -f 2`
#curl -o rules.tgz "https://api.esm.secbuzzer.co/esmapi/web/file/download/it/$current_rules_version" -H "accept: */*" -H "authorization: $API_KEY"
#tar zxvf rules.tgz -C tmp/rules
#sudo chown 1000:1000 tmp/* -R
#sudo rsync -r --delete tmp/rules/ Suricata/suricata/rules/
#rm -rf tmp rules.tgz
#else
#echo No API key found,Suricata rules download fail, check SecBuzzerESM.env
#fi

mkdir -p /opt/Logs/ES/volume/es
mkdir -p /opt/Logs/Suricata
mkdir -p /opt/Logs/Fluentd
mkdir -p /opt/Logs/Buffers

chown 1000 /opt/Logs -R
chmod go-w $BASEDIR/Packetbeat/packetbeat.docker.yml

rm -rf envimage
sudo docker network create esm_network 2>/dev/null || true

echo "Disable Swap"
swapoff -a
rm -rf /swap.img
sed -i 's/.*swap.*/#&/' /etc/fstab

if grep -q "\- interface\: eth0" /opt/SecBuzzerESM/Suricata/suricata/dist/suricata.yaml; then
  echo "Set Suricata capture config"
  IF_NAME=$(cat /opt/SecBuzzerESM/SecBuzzerESM.env | grep "^IF_NAME" | awk -F '=' {'print$2'})
  sed -i "0,/interface: eth0/{s/interface: eth0/interface: $IF_NAME/}" /opt/SecBuzzerESM/Suricata/suricata/dist/suricata.yaml
fi

#echo "set monitor agent key"

#apt-get install -y zabbix-agent
#which zabbix_agentd > /dev/null || (echo "monitor agent install fail"; exit)
#which openssl > /dev/null || (apt-gat install -y openssl ; which openssl) || (echo "openssl install fail"; exit)
#pskIdentity=`openssl rand -hex 12` 
#pskKey=`openssl rand -hex 32 | tee /etc/zabbix/zabbix_agentd.psk`

#ls /etc/zabbix/zabbix_agentd.conf > /dev/null || (echo "setup fail"; exit)
#sed -i "s/^\(# \|#\|\)StartAgents=.*/StartAgents=0/g" /etc/zabbix/zabbix_agentd.conf
#sed -i "s/^\(# \|#\|\)ServerActive=.*/ServerActive=host-monitor.secbuzzer.ai:30051/g" /etc/zabbix/zabbix_agentd.conf
#sed -i "s/^\(# \|#\|\)Hostname=.*/Hostname=`hostname`/g" /etc/zabbix/zabbix_agentd.conf
#sed -i "s/^\(# \|#\|\)TLSConnect=.*/TLSConnect=psk/g" /etc/zabbix/zabbix_agentd.conf
#sed -i "s/^\(# \|#\|\)TLSPSKIdentity=.*/TLSPSKIdentity=$pskIdentity/g" /etc/zabbix/zabbix_agentd.conf
#sed -i "s/^\(# \|#\|\)TLSPSKFile=.*/TLSPSKFile=\/etc\/zabbix\/zabbix_agentd.psk/g" /etc/zabbix/zabbix_agentd.conf

#systemctl enable zabbix-agent
#systemctl restart zabbix-agent

#egrep "^Hostname=" /etc/zabbix/zabbix_agentd.conf
#egrep "^TLSPSKIdentity=" /etc/zabbix/zabbix_agentd.conf
#echo TLSPSKKey=$pskKey

echo "Done!"
