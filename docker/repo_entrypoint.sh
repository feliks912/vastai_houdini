#!/bin/bash

# Decrypt the github files using crypt key
cd "/repo" || { echo "Can't cd to /repo"; exit 1; }

# Ensure the repository is clean
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

# Decode the GIT_CRYPT_KEY and unlock the repository
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

chmod +x /repo/**/*

# Start the necessary services and scripts in background
bash /repo/docker/netdata_start.sh &
# bash /repo/docker/license_installer.sh &

# Install necessary libraries
apt update && apt install libnsl* libGLU* libXss* libopengl-dev -y

# Setup environment
cd /houdini/houdini20.0 || exit 1
. ./houdini_setup
/usr/lib/sesi/sesinetd -p 1715 -n 1 -o -c &

sleep 1

cd "$OLDPWD" || exit 1

# Call the script to handle downloads
bash download_and_setup.sh

# Cleanup and finalize
rm /houdini/hqueue_client/hqnode.pid
echo "5001" | tee /houdini/hqueue_client/hqnode.port
echo -e "[main]\nserver = $HQUEUE_SERVER_IP\nport = $HQUEUE_SERVER_PORT\n[job_environment]" | tee /houdini/hqueue_client/hqnode.ini

# Start the log monitoring script in the background
bash /repo/docker/init_client.sh &

# Execute the passed commands
exec "$@"
