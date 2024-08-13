#!/bin/bash

echo "$RCLONE_BASE64_ENCRYPTED" | base64 --decode | tee "$(rclone config file | grep ".conf")"

: "${COMPRESSED_FILE_NAME:="new_project_files.tar.gz"}"

echo -e "[main]\nserver = $HQUEUE_SERVER_IP\nport = $HQUEUE_SERVER_PORT\n[job_environment]" | tee /houdini/hqueue_client/hqnode.ini

# Start the license server
/usr/lib/sesi/sesinetd start

sleep 2

#/usr/lib/sesi/sesictrl print-license

# Start the log monitoring script in the background
#bash /scripts/cloud_write_monitor.sh &

cd /

# Instead of exec "$@", you can try to run:
exec "$@"
