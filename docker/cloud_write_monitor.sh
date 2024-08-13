#!/bin/bash

# Default initialization if not set
: "${CLOUD_SYNC_INIT_WAIT_TIME:=5}"
: "${CLOUD_SYNC_NEXT_FILE_WAIT_TIME:=2}"

export HOUDINI_PROJECT_FOLDER=${HOUDINI_PROJECT_FOLDER:-"/houdini_projects"}

echo "houdini project folder: $HOUDINI_PROJECT_FOLDER"

# Ensure the project directory exists
mkdir -p "$HOUDINI_PROJECT_FOLDER"

function init_client(){
	rm /scripts/inotify.log

	inotifywait -m -r -e create -e modify --timefmt '%d-%m-%Y %H:%M:%S' --format '%T %w%f %e' "$HOUDINI_PROJECT_FOLDER" | while read -r DATE TIME FILE EVENT
	do
	    # Standardize the directory path by removing any trailing slash
	    standardized_project_dir="${HOUDINI_PROJECT_FOLDER%/}"
	
	    # Get the directory path of the file and standardize it
	    file_dir=$(dirname "$FILE")
	    standardized_file_dir="${file_dir%/}"
	
	    # Check if the file's directory is exactly the Houdini project folder and it's not a directory
	    if [[ "$standardized_file_dir" == "$standardized_project_dir" && ! -d "$FILE" ]]; then
	        # Ignore file events in the root of the Houdini project directory
	        continue
	    fi
	
	    # Log all other events
	    echo "$DATE $TIME $FILE $EVENT" >> /scripts/inotify.log
	done &

	/houdini/hqueue_client/hqclientd force-reload
	bash /scripts/log_monitor.sh &
}

# Format for timestamp
TIME_FORMAT="+%Y-%m-%d %H:%M:%S"

(sleep "$CLOUD_SYNC_INIT_WAIT_TIME" && init_client && echo "Writes were over before starting the instance" && exit 0) &
timer_pid=$!

# Use inotifywait to monitor directory for modifications, creations, or deletions
inotifywait -m -r -e modify -e create -e delete --timefmt "$TIME_FORMAT" --format '%T %:e %w%f' "$HOUDINI_PROJECT_FOLDER" | while read -r event_date event_time event path; do
    echo "Detected cloud write event $event at $event_date $event_time on path $path"
    # Reset the timer for the check
    kill $timer_pid 2>/dev/null
    (sleep "$CLOUD_SYNC_NEXT_FILE_WAIT_TIME" && init_client && echo "No more writes detected." && exit 0) &
    timer_pid=$!
done
