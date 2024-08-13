#!/bin/bash

# Check if the directory exists
if [ ! -d "$HOUDINI_PROJECT_FOLDER" ]; then
    mkdir -p $HOUDINI_PROJECT_FOLDER
fi

function init_client(){
	inotifywait -m -e create -e modify --timefmt '%d-%m-%Y %H:%M:%S' --format '%T %w%f %e' $HOUDINI_PROJECT_FOLDER | while read DATE TIME FILE EVENT
		do
		    if [[ ! "$FILE" =~ \.tar\.gz$ ]]; then
		        echo "$DATE $TIME $FILE $EVENT" >> /scripts/inotify.log
		    fi
		done &
	/houdini/hqueue_client/hqclientd force-reload
	bash /scripts/log_monitor.sh &
}

# Format for timestamp
TIME_FORMAT="+%Y-%m-%d %H:%M:%S"

(sleep 5 && init_client && echo "Writes were over before starting the instance" && exit 0) &
timer_pid=$!

# Use inotifywait to monitor directory for modifications, creations, or deletions
inotifywait -m -r -e modify -e create -e delete --timefmt "$TIME_FORMAT" --format '%T %:e %w%f' $HOUDINI_PROJECT_FOLDER | while read event_date event_time event path; do
    echo "Detected $event at $event_date $event_time on $path"
    # Reset the timer for the check
    kill $timer_pid 2>/dev/null
    (sleep 2 && init_client && echo "No more writes detected." && exit 0) &
    timer_pid=$!
done
