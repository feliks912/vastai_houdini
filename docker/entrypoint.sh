#!/bin/bash

echo "$RCLONE_BASE64_ENCODED" | base64 --decode | tee "$(rclone config file | grep '.conf')"

echo "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/${PROJECT_FOLDER_NAME%/}/"
echo "${HOUDINI_PROJECTS_PATH%/}/${PROJECT_FOLDER_NAME%/}"

# Get the number of CPU threads
total_threads=$(nproc --all)

# Calculate n-1 threads
usable_threads=$((total_threads - 1))

# Half of usable threads for transfers and checkers
transfers=$((usable_threads / 3))
checkers=$((usable_threads / 3))

# A smaller fraction for multi-thread streams, adjust according to needs
multi_thread_streams=$((usable_threads / 3))

# Rclone command with dynamic threading settings
rclone copy -vv "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/${PROJECT_FOLDER_NAME%/}/" "${HOUDINI_PROJECTS_PATH%/}/${PROJECT_FOLDER_NAME%/}" \
  --transfers $transfers \
  --checkers $checkers \
  --multi-thread-streams $multi_thread_streams \
  --buffer-size 512M \
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
