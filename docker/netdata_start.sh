#!/bin/bash

CONFIG_FILE="/etc/netdata/stream.conf"

cp /usr/lib/netdata/conf.d/stream.conf $CONFIG_FILE

set -a; source /repo/docker/.env; set +a

# Perform the replacements
sed -i "0,/destination =/s//destination =$NETDATA_SERVER_IP:$NETDATA_SERVER_PORT/" "$CONFIG_FILE"
sed -i "0,/#ssl skip certificate verification = yes/s//ssl skip certificate verification = yes/" "$CONFIG_FILE"
sed -i "0,/enabled = no/s//enabled = yes/" "$CONFIG_FILE"
sed -i "0,/api key =/s//api key=$NETDATA_API_KEY/" "$CONFIG_FILE"

# Restart the Netdata service
if ! sudo service netdata restart; then
  sudo service netdata start
fi

echo "Netdata configuration updated and service restarted."