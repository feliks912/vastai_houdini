#!/bin/bash

: "${COMPRESSED_FILE_NAME:="new_project_files.tar.gz"}"

# Generate a new list of all files and their MD5 checksums
find "${HOUDINI_PROJECTS_PATH%/}" -type f -exec md5sum {} + > "/tmp/final_checksums.md5"

# Compare initial and final checksums, extract filenames for changed or new files
comm -13 <(sort "/tmp/initial_checksums.md5") <(sort "/tmp/final_checksums.md5") | awk '{print $2}' | sed "s|^${HOUDINI_PROJECTS_PATH%/}/||" > "/tmp/files_to_compress.txt"

echo "Files to compress from /tmp/files_to_compress:"
cat /tmp/files_to_compress.txt

# Number of files to compress
num_files=$(wc -l < "/tmp/files_to_compress.txt")
echo "Number of files to compress: $num_files"

if [ "$num_files" -eq 0 ]; then
    echo "No files to compress. Exiting."
    exit 0
fi

# Move into the directory for relative path compression
cd "$HOUDINI_PROJECTS_PATH" || exit

# Compress the files
if tar -cf "$COMPRESSED_FILE_NAME" -C "${HOUDINI_PROJECTS_PATH%/}/" -T "/tmp/files_to_compress.txt" --use-compress-program="pigz -p $(nproc --ignore=1) -9"; then
    echo "Compression completed successfully."
else
    echo "Compression failed."
fi

#begin compression

total_threads=$(nproc --all)

# Calculate n-1 threads
usable_threads=$((total_threads - 1))

# Half of usable threads for transfers and checkers
transfers=$((usable_threads / 3))
checkers=$((usable_threads / 3))

# A smaller fraction for multi-thread streams, adjust according to needs
multi_thread_streams=$((usable_threads / 3))

rclone copy -vv --config /repo/docker/rclone.conf "${HOUDINI_PROJECTS_PATH%/}/" "${RCLONE_GCLOUD_NAME%/}:${GCLOUD_ROOT_PROJECTS_FOLDER%/}/" \
  --transfers $transfers \
  --checkers $checkers \
  --multi-thread-streams $multi_thread_streams \
  --buffer-size 256M \
  --drive-chunk-size 256M \
  --drive-pacer-min-sleep 10ms \
  --drive-pacer-burst 200 \
  --update \
  --ignore-existing
