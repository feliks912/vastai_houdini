# Remove any previous checksums file
rm -f "/tmp/initial_checksums.md5"

# Generate a list of all files and their MD5 checksums
# Using 'find' to locate all files and 'md5sum' to generate checksums
# Using 'sort' to ensure consistent order for later comparison
find "${HOUDINI_PROJECTS_PATH%/}" -type f -print0 | xargs -0 md5sum | sort > "/tmp/initial_checksums.md5"

echo "Initial checksums recorded."

/houdini/hqueue_client/hqclientd start

stty sane
echo -e '\033c'

bash /repo/docker/log_monitor.sh &