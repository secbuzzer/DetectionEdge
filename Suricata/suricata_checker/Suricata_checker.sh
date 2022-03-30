set -euo pipefail

#    ____       _   _    ____                  ____     _       _____      _      
#   / __"| u U |"|u| |U |  _"\ u     ___    U /"___|U  /"\  u  |_ " _| U  /"\  u  
#  <\___ \/   \| |\| | \| |_) |/    |_"_|   \| | u   \/ _ \/     | |    \/ _ \/   
#   u___) |    | |_| |  |  _ <       | |     | |/__  / ___ \    /| |\   / ___ \   
#   |____/>>  <<\___/   |_| \_\    U/| |\u    \____|/_/   \_\  u |_|U  /_/   \_\  
#    )(  (__)(__) )(    //   \\_.-,_|___|_,-._// \\  \\    >>  _// \\_  \\    >>  
#   (__)         (__)  (__)  (__)\_)-' '-(_/(__)(__)(__)  (__)(__) (__)(__)  (__) 
#     ____   _   _  U _____ u   ____   _  __  U _____ u   ____                    
#  U /"___| |'| |'| \| ___"|/U /"___| |"|/ /  \| ___"|/U |  _"\ u                 
#  \| | u  /| |_| |\ |  _|"  \| | u   | ' /    |  _|"   \| |_) |/                 
#   | |/__ U|  _  |u | |___   | |/__U/| . \\u  | |___    |  _ <                   
#    \____| |_| |_|  |_____|   \____| |_|\_\   |_____|   |_| \_\                  
#   _// \\  //   \\  <<   >>  _// \\,-,>> \\,-.<<   >>   //   \\_                 
#  (__)(__)(_") ("_)(__) (__)(__)(__)\.)   (_/(__) (__) (__)  (__)                

ESIPPORT=localhost:19200

function pexit {
    # https://stackoverflow.com/a/24597941
    echo "$1" >> /var/log/cron.log  ## Send message to stderr. Exclude >&2 if you don't want it that way.
    exit "${2-1}"  ## Return a code specified by $2 or 1 by default.
}
echo "[*] `date +"%Y-%m-%d %H:%M"` Exec Suricata checker" >> /var/log/cron.log

# if Elasticsearch dead then exit
# curl -s --fail --show-error ${ESIPPORT} >> /dev/null || pexit "Elasticsearch maybe dead :(, Bye" $?

# sending test request!
/usr/bin/tcpreplay -i $IF_NAME /image/suricata.pcap

QDATE=`date +"%Y-%m-%dT%H"`
INDEXDATE=`date +"%Y-%m"`
n=0
until [ "$n" -ge 10 ]
do
    QUERY_RESULT=`curl -s 'http://'${ESIPPORT}'/suricata-'${INDEXDATE}'/_search' \
      -H 'Content-Type: application/json' \
      --data-binary '{"query":{"bool":{"must":[{"term":{"alert.signature_id":"66778899"}},{"range":{"@timestamp":{"gt":"'${QDATE}':00:00.000000000+08:00","lt":"'${QDATE}':59:59.999999999+08:00"}}}],"must_not":[],"should":[]}},"from":0,"size":10,"sort":[],"aggs":{}}' \
      --compressed \
      --insecure | jq '.["hits"]["total"]["value"]'`
    echo "[*] Try times: $((n+1))" >> /var/log/cron.log
    if [ ${QUERY_RESULT} == 'null' ]
    then 
    QUERY_RESULT=0
    fi
    [ ${QUERY_RESULT} -gt 0 ] && pexit "[*] `date +"%Y-%m-%d %H:%M"` Suricata is alive :D" $?  # substitute your command here
    n=$((n+1)) 
    sleep 60
done
echo "[*] `date +"%Y-%m-%d %H:%M"` Suricata is dead, restart suricata" >> /var/log/cron.log
curl -XPOST --unix-socket /var/run/docker.sock http://localhost/containers/suricata/restart
