#!/bin/bash
[ `ps -p $$ -o comm=""` != `echo $0 | sed 's/^.\///g'` ] && [ `ps -p $$ -o comm=""` != 'bash' ] && (echo Please run on bash; exit)
[ `id -u` = 0 ] || (echo sudo $0; exit)
apt-get install -y zabbix-agent
which zabbix_agentd > /dev/null || (echo "monitor agent install fail"; exit)
which openssl > /dev/null || (apt-gat install -y openssl ; which openssl) || (echo "openssl install fail"; exit)
pskIdentity=`openssl rand -hex 12` 
pskKey=`openssl rand -hex 32 | tee /etc/zabbix/zabbix_agentd.psk`

ls /etc/zabbix/zabbix_agentd.conf > /dev/null || (echo "setup fail"; exit)
sed -i "s/^\(# \|#\|\)StartAgents=.*/StartAgents=0/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^\(# \|#\|\)ServerActive=.*/ServerActive=host-monitor.secbuzzer.ai:30051/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^\(# \|#\|\)Hostname=.*/Hostname=`hostname`/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^\(# \|#\|\)TLSConnect=.*/TLSConnect=psk/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^\(# \|#\|\)TLSPSKIdentity=.*/TLSPSKIdentity=$pskIdentity/g" /etc/zabbix/zabbix_agentd.conf
	sed -i "s/^\(# \|#\|\)TLSPSKFile=.*/TLSPSKFile=\/etc\/zabbix\/zabbix_agentd.psk/g" /etc/zabbix/zabbix_agentd.conf

	systemctl enable zabbix-agent
systemctl restart zabbix-agent

egrep "^Hostname=" /etc/zabbix/zabbix_agentd.conf
egrep "^TLSPSKIdentity=" /etc/zabbix/zabbix_agentd.conf
echo TLSPSKKey=$pskKey
