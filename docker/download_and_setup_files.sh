#!/bin/bash

# Decode and export the authentication string from rclone.conf
authstring=$(awk -F "=" '/account/{acc=$2} /key/{key=$2} END{print acc ":" key}' ./rclone.conf | tr -d ' ' | base64)

# Read and split the FILES_TO_DOWNLOAD into an array
IFS=',' read -r -a files_to_download <<< "$FILES_TO_DOWNLOAD"
num_files=${#files_to_download[@]}

total_threads=$(nproc --all)
usable_threads=$((total_threads - 1))
per_file_threads=$((usable_threads / num_files))

# Function to handle downloads
download_files() {
    local file_name="$1"
    rclone copy -vv --b2-download-url https://01042010.xyz --header "workerauth:${authstring}" \
      "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/${file_name%/}/" \
      "${HOUDINI_PROJECTS_PATH%/}/${file_name%/}" \
      --transfers $per_file_threads \
      --checkers $per_file_threads \
      --multi-thread-streams $per_file_threads \
      --buffer-size 512M \
      --drive-chunk-size 256M \
      --drive-pacer-min-sleep 10ms \
      --drive-pacer-burst 200 \
      --no-traverse \
      --create-empty-src-dirs
}

# Loop over the files to download
for file in "${files_to_download[@]}"; do
    download_files "$file"
done
