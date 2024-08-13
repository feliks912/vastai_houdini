#!/bin/bash

echo "$RCLONE_BASE64_ENCRYPTED" | base64 --decode | tee "$(rclone config file | grep '.conf')"

rclone copy "$RCLONE_GCLOUD_NAME:$GCLOUD_ROOT_PROJECTS_FOLDER/$PROJECT_FOLDER_NAME/" "$HOUDINI_PROJECTS_PATH/$PROJECT_FOLDER_NAME" \
  --transfers 32 \
  --checkers 32 \
  --multi-thread-streams 8 \
  --buffer-size 256M \
  --drive-chunk-size 256M \
  --drive-pacer-min-sleep 10ms \
  --drive-pacer-burst 200 \
  --no-traverse \
  --create-empty-src-dirs

echo -e "[main]\nserver = $HQUEUE_SERVER_IP\nport = $HQUEUE_SERVER_PORT\n[job_environment]" | tee /houdini/hqueue_client/hqnode.ini

# Start the license server
/usr/lib/sesi/sesinetd start

sleep 2

#/usr/lib/sesi/sesictrl print-license

# Start the log monitoring script in the background
bash /scripts/init_client.sh &

cd /

# Instead of exec "$@", you can try to run:
exec "$@"
