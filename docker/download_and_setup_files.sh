#!/bin/bash

# Decode and export the authentication string from rclone.conf
authstring=$(awk -F"=" '/account/{acc=$2} /key/{key=$2} END{print acc ":" key}' ./rclone.conf | tr -d '[:space:]' | base64 -w 0)

# Create a temporary file to store the list of files to download
echo "$FILES_TO_DOWNLOAD" | tr ',' '\n' > files_to_download.txt

total_threads=$(nproc --all)
usable_threads=$((total_threads - 1))  # Use all but one thread

# Function to handle downloads
download_files() {
    echo "Downloading files listed in files_to_download.txt"
    rclone copy -vv --config /repo/docker/rclone.conf --b2-download-url https://01042010.xyz --header "workerauth:Basic ${authstring}" \
      "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/" \
      "${HOUDINI_PROJECTS_PATH%/}/" \
      --files-from files_to_download.txt \
      --transfers $usable_threads \
      --checkers $usable_threads \
      --multi-thread-streams $usable_threads \
      --buffer-size 512M \
      --drive-chunk-size 256M \
      --drive-pacer-min-sleep 10ms \
      --drive-pacer-burst 200 \
      --no-traverse \
      --create-empty-src-dirs
}

# Call the function to start download
download_files

# Clean up the temporary file
rm files_to_download.txt
