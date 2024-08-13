#!/bin/bash

# Path to the log file
LOG_FILE="/scripts/inotify.log"

: "${COMPRESSED_FILE_NAME:="new_project_files.tar.gz"}"

# Output tar file
OUTPUT_TAR="$HOUDINI_PROJECT_FOLDER/$COMPRESSED_FILE_NAME"

# Determine the number of CPU cores to use (n-1)
CPU_COUNT=$(nproc --ignore=1)

echo "Detected CPU cores for compression: $CPU_COUNT"

# Extract files to compress, ensuring unique entries
awk '{print $3}' $LOG_FILE | sort -u > files_to_compress.txt

# Debug: Check the content size of files_to_compress.txt
echo "Number of files to compress: $(wc -l < files_to_compress.txt)"

# Compress the files with maximum compression using pigz with n-1 threads
echo "Starting compression..."
rm -f "$HOUDINI_PROJECT_FOLDER/*.tar.gz"
tar -c --use-compress-program="pigz -p $CPU_COUNT -9" -f "$OUTPUT_TAR" -T files_to_compress.txt

# Check exit status of the tar command
if ! tar -c --use-compress-program="pigz -p $CPU_COUNT -9" -f "$OUTPUT_TAR" -T files_to_compress.txt; then
    echo "Compression completed successfully."
else
    echo "Compression failed."
fi
