#/bin/sh

print_log() {
    case "$1" in
        Info)
            echo `date '+%d/%m/%Y -- %H:%M:%S'` "- <$1> - $2"
        ;;
        Warning)
            echo `date '+%d/%m/%Y -- %H:%M:%S'` "- <$1> - $2"
        ;;
        Error)
            echo `date '+%d/%m/%Y -- %H:%M:%S'` "- <$1> - $2"
        ;;
    esac
}

MODE=`printenv DEV_MODE | tr [:upper:] [:lower:]`

if [ "$MODE" == "" ] || [ "$MODE" != "true" ]; then
    ESM_URL="api.esm.secbuzzer.co"
else
    print_log Info "Suricata Run Dev Mode."
    ESM_URL="test.api.esm.secbuzzer.co"
fi

if timeout 2 ping -c 2 $ESM_URL &> /dev/null; then
  print_log Info "ESM API Server Connection."
else
  print_log Error "ESM API Server Fail."
  exit
fi



SURICATA_CMD="suricata -v -i ${IF_NAME} --set vars.address-groups.HOME_NET=${HOME_NET:-any} -c /etc/suricata/suricata.yaml -D"
ESM_API=`printenv API_KEY_VALUE`
CLOUD_IT_VER=`curl -s -X POST "https://$ESM_URL/esmapi/web/file/fileVersion" -d "{'TypeCode': 'it'}" -H "Content-Type: application/json" -H "accept: */*" -H "authorization: $ESM_API" | cut -d : -f 2 | cut -d \" -f 2`
CLOUD_DTM_VER=`curl -s -X POST "https://$ESM_URL/esmapi/web/file/fileVersion" -d "{'TypeCode': 'dtm'}" -H "Content-Type: application/json" -H "accept: */*" -H "authorization: $ESM_API" | cut -d : -f 2 | cut -d \" -f 2`
EDGE_IT_VER=`cat /etc/suricata/version/it 2>/dev/null`
EDGE_DTM_VER=`cat /etc/suricata/version/dtm 2>/dev/null`
EDGE_IT_COUNT=`find /etc/suricata/rules/it -name *.rules | wc -l`
EDGE_DTM_COUNT=`find /etc/suricata/rules/dtm -name *.rules | wc -l`
FLAG_RULES=0

check_esm_env() {
    # Check ENV
    if [ "$ESM_API" == "" ]; then
        print_log Error "ESM API_KEY_VALUE Not Found."
        exit
    fi

    if [ "$CLOUD_IT_VER" == "Invalid authentication credentials" ] || [ "$CLOUD_DTM_VER" == "Invalid authentication credentials" ]; then
        print_log Error "ESM API_KEY_VALUE Invalid authentication credentials."
        exit
    fi

    # Check Rules Ver File
    if [ "$EDGE_IT_VER" == "" ] || [ "$EDGE_DTM_VER" == "" ]; then
        print_log Warning "ESM Rules Version File Not Found."
    fi

    if [ "$EDGE_IT_VER" == "" ]; then
        touch /etc/suricata/version/it
        echo "0" > /etc/suricata/version/it
        EDGE_IT_VER=`cat /etc/suricata/version/it 2>/dev/null`
    fi

    if [ "$EDGE_DTM_VER" == "" ]; then
        touch /etc/suricata/version/dtm
        echo "0" > /etc/suricata/version/dtm
        EDGE_DTM_VER=`cat /etc/suricata/version/dtm 2>/dev/null`
    fi
}


check_rules_it() {
    if [ "$EDGE_IT_VER" != "$CLOUD_IT_VER" ] || [ "$EDGE_IT_COUNT" == 0 ]; then
        print_log Info "IT Rules New version found, Rules update to $CLOUD_IT_VER"
        curl -s -o /tmp/it_"$CLOUD_IT_VER".tgz "https://$ESM_URL/esmapi/web/file/download/it/$CLOUD_IT_VER" -H "accept: */*" -H "authorization: $ESM_API"
        mkdir -p /tmp/it_rules
        tar zxf /tmp/it_"$CLOUD_IT_VER".tgz -C /tmp/it_rules
        rsync -a --delete /tmp/it_rules/ /etc/suricata/rules/it/
        echo $CLOUD_IT_VER > /etc/suricata/version/it
        FLAG_RULES=$((FLAG_RULES + 1))
    fi
}

check_rules_dtm() {
    if [ "$EDGE_DTM_VER" != "$CLOUD_DTM_VER" ] || [ "$EDGE_DTM_COUNT" == 0 ]; then
        print_log Info "DTM Rules New version found, Rules update to $CLOUD_DTM_VER"
        curl -s -o /tmp/dtm_"$CLOUD_DTM_VER".tgz "https://$ESM_URL/esmapi/web/file/download/dtm/$CLOUD_DTM_VER" -H "accept: */*" -H "authorization: $ESM_API"
        mkdir -p /tmp/dtm_rules
        tar zxf /tmp/dtm_"$CLOUD_DTM_VER".tgz -C /tmp/dtm_rules
        rsync -a --delete /tmp/dtm_rules/ /etc/suricata/rules/dtm/
        echo $CLOUD_DTM_VER > /etc/suricata/version/dtm
        FLAG_RULES=$((FLAG_RULES + 2))
    fi
}

merge_rules_classification() {
    case "$FLAG_RULES" in
        # it rule update, dtm rule no update.
        1)
            cat /tmp/it_rules/classification.config /etc/suricata/rules/dtm/classification.config | sort | uniq > /etc/suricata/classification.config
        ;;
        # it rule no update, dtm rule update.
        2)
            cat /etc/suricata/rules/it/classification.config /tmp/dtm_rules/classification.config | sort | uniq > /etc/suricata/classification.config
        ;;
        # rule update, dtm rule no update.
        3)
            cat /tmp/it_rules/classification.config /tmp/dtm_rules/classification.config | sort | uniq > /etc/suricata/classification.config
        ;;
        # no update
        *)
            return
        ;;
    esac
    print_log Info "Merge Rules Classification File."
}

check_service_suricata() {
    local suricata_ps=`ps | grep "Suricata-Main" | grep -v grep`
    # Suricata Service Start
    if [ "$suricata_ps" == "" ]; then
    	rm -rf /var/run/suricata.pid 2>/dev/null
        eval $SURICATA_CMD
        return
    fi
    # Suricata Service Restart
    if [ "$FLAG_RULES" != 0 ] && [ "$suricata_ps" != "" ]; then
        rm -rf /var/run/suricata.pid 2>/dev/null
        pkill -f "suricata -v -i"
        print_log Info "Restarting Suricata."
        eval $SURICATA_CMD
        return
    fi
}

clean_tmp() {
    rm /tmp/*.tgz 2>/dev/null
    rm -rf /tmp/dtm_rules/ 2>/dev/null
    rm -rf /tmp/it_rules/ 2>/dev/null
}

check_esm_env
check_rules_it
check_rules_dtm
merge_rules_classification
check_service_suricata
clean_tmp
