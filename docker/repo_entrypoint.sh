#!/bin/bash

# Decrypt the github files using crypt key

cd "/repo" || { echo "Can't cd to /repo"; exit 1; }

if [ -z "$(git status --porcelain)" ]; then
    echo "Repository is clean. Proceeding..."
else
    echo "Repository is not clean. Attempting to clean..."
    git reset --hard
    git clean -fdx
    if [ -z "$(git status --porcelain)" ]; then
        echo "Cleanup successful. Proceeding..."
    else
        echo "Failed to clean the repository. Exiting..."
        exit 1
    fi
fi


if echo "$GIT_CRYPT_KEY" | base64 --decode > /tmp/keyfile; then
    if git-crypt unlock /tmp/keyfile; then
        echo "Unlock successful."
        rm /tmp/keyfile
    else
        echo "Unlock failed."
        rm /tmp/keyfile
        exit 1
    fi
else
    echo "Failed to decode key."
    exit 1
fi

bash /repo/docker/netdata_start.sh &

#bash /repo/docker/license_installer.sh &

tee "$(rclone config file | grep '.conf')" < /repo/docker/rclone.conf

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

rm /houdini/hqueue_client/hqnode.pid
echo "5001" | tee /houdini/hqueue_client/hqnode.port
echo -e "[main]\nserver = $HQUEUE_SERVER_IP\nport = $HQUEUE_SERVER_PORT\n[job_environment]" | tee /houdini/hqueue_client/hqnode.ini

# Start the log monitoring script in the background
bash /repo/docker/init_client.sh &

cd /

# Instead of exec "$@", you can try to run:
exec "$@"
