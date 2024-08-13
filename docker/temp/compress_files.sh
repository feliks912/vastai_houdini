#!/bin/bash

# Path to the log file
LOG_FILE="/scripts/inotify.log"

# Output tar file
OUTPUT_TAR="$HOUDINI_PROJECT_FOLDER/new_project_files.tar.gz"

# Determine the number of CPU cores to use (n-1)
CPU_COUNT=$(($(nproc) --ignore=1))

# Extract files to compress, ensuring unique entries
awk '{print $2}' $LOG_FILE | sort -u > files_to_compress.txt

# Compress the files with maximum compression using pigz with n-1 threads
tar -c --use-compress-program="pigz -p $CPU_COUNT -9" -f $OUTPUT_TAR -T files_to_compress.txt
