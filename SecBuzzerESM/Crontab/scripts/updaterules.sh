#/bin/bash

/usr/bin/python3 -u /scripts/it_updater.py >> /var/log/cron.log
/usr/bin/python3 -u /scripts/dtm_updater.py >> /var/log/cron.log
curl -XPOST --unix-socket /var/run/docker.sock -H "Content-Type: application/json" http://localhost/containers/suricata/restart
