#/bin/sh


path_deny="/tmp/deny"
suricata_deny=`cat $path_deny 2>/dev/null`
suricata_ps=`ps | grep "Suricata-Main" | grep -v grep`
conatiner_name="suricata"

# Suricata Runing
if [ "$suricata_ps" != "" ]; then
	echo "0" > $path_deny
	return
fi

# Suricata no Runing
if [ "$suricata_deny" == "" ]; then
	deny_count=0
else
	deny_count="$suricata_deny"
fi

if [ `echo "$deny_count >= 10"|bc` -eq 1 ]; then
	echo "0" > $path_deny
	echo `date '+%d/%m/%Y -- %H:%M:%S'` "- <Error> - Kill Suricata Container."
	# kill tail = container status Exited
	curl -XPOST --unix-socket /var/run/docker.sock -H "Content-Type: application/json" http://localhost/containers/"$conatiner_name"/stop
	return
fi

deny_count=$((deny_count + 1))
echo `date '+%d/%m/%Y -- %H:%M:%S'` "- <Warning> - Not found Suricata Service. ${deny_count}"
echo $deny_count > $path_deny
