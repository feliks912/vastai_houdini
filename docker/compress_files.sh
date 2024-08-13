#!/bin/bash

# Path to the log file
LOG_FILE="/scripts/inotify.log"

: "${COMPRESSED_FILE_NAME:="new_project_files.tar.gz"}"

# Output tar file
OUTPUT_TAR="${HOUDINI_PROJECTS_PATH%/}/${COMPRESSED_FILE_NAME}"

# Determine the number of CPU cores to use (n-1)
CPU_COUNT=$(nproc --ignore=1)

echo "Detected CPU cores for compression: $CPU_COUNT"

# Extract files to compress, ensuring unique entries
awk '{print $3}' $LOG_FILE | sort -u > files_to_compress.txt

# Debug: Check the content size of files_to_compress.txt
num_files=$(wc -l < files_to_compress.txt)
echo "Number of files to compress: $num_files"

if [ "$num_files" -eq 0 ]; then
    echo "No files to compress. Exiting."
    exit 0
fi

# Compress the files with maximum compression using pigz with n-1 threads
echo "Starting compression..."
rm -f "${HOUDINI_PROJECTS_PATH%/}/*.tar.gz"
tar -c --use-compress-program="pigz -p $CPU_COUNT -9" -f "$OUTPUT_TAR" -T files_to_compress.txt

# Check exit status of the tar command
if ! tar -c --use-compress-program="pigz -p $CPU_COUNT -9" -f "$OUTPUT_TAR" -T files_to_compress.txt; then
    echo "Compression completed successfully."
else
    echo "Compression failed."
fi

total_threads=$(nproc --all)

# Calculate n-1 threads
usable_threads=$((total_threads - 1))

# Half of usable threads for transfers and checkers
transfers=$((usable_threads / 3))
checkers=$((usable_threads / 3))

# A smaller fraction for multi-thread streams, adjust according to needs
multi_thread_streams=$((usable_threads / 3))

rclone copy "${HOUDINI_PROJECTS_PATH%/}/" "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/" \
  --transfers $transfers \
  --checkers $checkers \
  --multi-thread-streams $multi_thread_streams \
  --buffer-size 256M \
  --drive-chunk-size 256M \
  --drive-pacer-min-sleep 10ms \
  --drive-pacer-burst 200 \
  --update \
  --ignore-existing
