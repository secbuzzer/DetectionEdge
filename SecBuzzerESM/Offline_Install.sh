#!/bin/sh
set -euo pipefail
# set -ex # for debug
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

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

if [ -f "/usr/bin/docker" ]; then
    echo "[*] Already install docker!"
else
    echo "[*] Install docker & docker-compose"
    source install_docker.sh
fi

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

mkdir -p /opt/Logs/ES/volume/es
mkdir -p /opt/Logs/ES/volume/es1
mkdir -p /opt/Logs/ES/volume/es2
mkdir -p /opt/Logs/Suricata
mkdir -p /opt/Logs/Fluentd
mkdir -p /opt/Logs/Buffers

chown 1000 /opt/Logs -R
chmod go-w $BASEDIR/Packetbeat/packetbeat.docker.yml

echo "Disable Swap"
swapoff -a
rm -rf /swap.img
sed -i 's/.*swap.*/#&/' /etc/fstab

gunzip -c $BASEDIR/envimage/SecBuzzerESM.tgz | sudo docker load
sudo docker network create esm_network 2>/dev/null || true

if grep -q "\- interface\: eth0" /opt/SecBuzzerESM/Suricata/suricata/dist/suricata.yaml; then
  echo "Set Suricata capture config"
  IF_NAME=$(cat /opt/SecBuzzerESM/SecBuzzerESM.env | grep "^IF_NAME" | awk -F '=' {'print$2'})
  sed -i "0,/interface: eth0/{s/interface: eth0/interface: $IF_NAME/}" /opt/SecBuzzerESM/Suricata/suricata/dist/suricata.yaml
fi

echo "Done!"
