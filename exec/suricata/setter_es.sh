#/bin/sh

check_wait() {
	local CMD='curl localhost:19200/_template 2>/dev/null'
	flag=0
	while :
	do
		cmd_value=$(eval "$CMD")
		if [ "$cmd_value" != "" ]; then
			return
		fi
		flag=$((flag + 1))
		sleep 2
		# 5m
		if [ `echo "$flag >= 150"|bc` -eq 1 ]; then
			exit
		fi
	done
}

check_wait

# elasticsearch set replicas to 0
curl -XPUT "localhost:19200/_template/replicas_0" -H 'Content-Type: application/json' -d'{"index_patterns": ["*"],"settings": {"number_of_replicas": 0}}' >/dev/null 2>&1
