API_KEY=`cat SecBuzzerESM.env | grep API_KEY_VALUE | cut -d = -f 2`
if [ -n "$API_KEY" ]
then
mkdir -p tmp/dtm_rules
current_rules_version=`curl -X POST "https://api.esm.secbuzzer.co/esmapi/web/file/fileVersion" -d "{'TypeCode': 'dtm'}" -H "Content-Type: application/json" -H "accept: */*" -H "authorization: $API_KEY" | cut -d : -f 2 | cut -d \" -f 2`
curl -o dtm_rules.tgz "https://api.esm.secbuzzer.co/esmapi/web/file/download/dtm/$current_rules_version" -H "accept: */*" -H "authorization: $API_KEY"
tar zxvf dtm_rules.tgz -C tmp/dtm_rules
sudo chown 1000:1000 /tmp/* -R
sudo rsync -r --delete tmp/dtm_rules/ Suricata/suricata/rules/dtm/
rm -rf tmp dtm_rules.tgz
docker-compose --env-file SecBuzzerESM.env -f Suricata/docker-compose.yml restart
else
echo No API key found, Suricata rules download fail, check SecBuzzerESM.env
fi 
