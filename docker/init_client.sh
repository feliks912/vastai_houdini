rm /scripts/inotify.log # In case the instance has stopped, not been terminated

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