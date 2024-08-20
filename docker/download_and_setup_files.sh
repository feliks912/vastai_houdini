#!/bin/bash

# Decode and export the authentication string from rclone.conf
authstring=$(awk -F"=" '/account/{acc=$2} /key/{key=$2} END{print acc ":" key}' /repo/docker/rclone.conf | tr -d '[:space:]' | base64 -w 0)

# Define the total number of processor threads and calculate usable threads
total_threads=$(nproc --all)
usable_threads=$((total_threads - 1))  # Use all but one thread to prevent system lock-up

# Function to handle downloads
download_files() {
    if [ -z "$FILES_TO_DOWNLOAD" ]; then
        echo "Downloading the entire folder because FILES_TO_DOWNLOAD is empty."
        rclone copy -vv --config /repo/docker/rclone.conf --b2-download-url https://01042010.xyz --header "workerauth:Basic ${authstring}" \
          "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/" \
          "${HOUDINI_PROJECTS_PATH%/}/" \
          --transfers $usable_threads \
          --checkers $usable_threads \
          --multi-thread-streams $usable_threads \
          --buffer-size 512M \
          --drive-chunk-size 256M \
          --drive-pacer-min-sleep 10ms \
          --drive-pacer-burst 200 \
          --no-traverse \
          --create-empty-src-dirs
    else
        echo "Downloading files listed in files_to_download.txt"
        echo "$FILES_TO_DOWNLOAD" | tr ',' '\n' > files_to_download.txt
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
        rm files_to_download.txt  # Clean up the temporary file after download
    fi
}

# Call the function to start the download
download_files
