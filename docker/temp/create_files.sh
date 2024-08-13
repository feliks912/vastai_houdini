cat <<'EOF' >/scripts/cloud_write_monitor.sh
#!/bin/bash

# Check if the directory exists
if [ ! -d "$HOUDINI_PROJECT_FOLDER" ]; then
    mkdir -p $HOUDINI_PROJECT_FOLDER
fi

function init_client(){
	inotifywait -m -e create -e modify --timefmt '%d-%m-%Y %H:%M:%S' --format '%T %w%f %e' $HOUDINI_PROJECT_FOLDER >> /scripts/inotify.log &
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
EOF

cat <<'EOF' >/scripts/compress_files.sh
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
EOF

cat <<'EOF' >/scripts/entrypoint.sh
#!/bin/bash

if [ -z "$HOUDINI_PROJECT_FOLDER" ]; then
    # If not set, define it
    export HOUDINI_PROJECT_FOLDER="/houdini_projects"
fi

# Run initial license setup using sesictrl
cd /houdini/houdini20.0 || exit 1
. ./houdini_setup

touch /usr/lib/sesi/licenses
sed -i 's/^enableIPv6=true/enableIPv6=false/' /usr/lib/sesi/sesinetd.ini
/usr/lib/sesi/sesinetd -p 1715 -n 1 -o -c

sleep 2

# The following will simulate running the license command based on the current server ID
server_id=$(sesictrl print-server | grep ^SERVER | awk '{print $3}')

echo "$server_id"

sesictrl install SERVER localhost "$server_id" 9ED008858DFEE0E52C3C2D828C470F92EAD142325A3D02

sesictrl install LICENSE Generic Houdini-Master 20.0 100 25-dec-2030 *.*.*.* localhost de2e1b68 OSWGdzB0Trhoo26fAx3PzFjlQHn2mqkXvZXP@n0psW5T3qeaI+5ghTXBpdMdtgycF+BWO0+w6iy538
sesictrl install LICENSE Generic Houdini-Master-NG 20.0 100 25-dec-2030 *.*.*.* localhost f983e840 rY@K9WrZTt@mgWl@iKEd2IHJ5n1ckpzWfcOgOP7J1T1PAyy6+m5NPr@ZeW59h3kbsRhnSTdl1EPrU8
sesictrl install LICENSE Generic Houdini-Render 20.0 100 25-dec-2030 *.*.*.* localhost d413e785 XhSH781@BV895snZMqao1W5@FMpPhqPlVO8oGrAuercpK@WfqtsDWKmXJLjZChtGqWVVqDEAibbEN6
sesictrl install LICENSE Generic Houdini-Halo 20.0 100 25-dec-2030 *.*.*.* localhost 93fc7e1a dkp9LU5qepSvBiPrPvdkqKHuzJzTmQn+71ixMr6tRyaqBmMP2axIBiaVmQEMvDJkwgh3YWEnL0wms7
sesictrl install LICENSE Generic Houdini-Halo-NG 20.0 100 25-dec-2030 *.*.*.* localhost d8abfa73 Sd5iUt14v6mX7oXhQfMHukuQweAvQAzuyv1oVUC53ARL50GAXr6wKi+1mgXFMvDrDgMUNoOpGopCJA
sesictrl install LICENSE Generic Houdini-Escape 20.0 100 25-dec-2030 *.*.*.* localhost 43047c51 0Rvgsvvwjr3SX6c3FE2tQviLhY7gq5zcv7sVuw43GqThuAyTXS+aAGXHNnrNfrpm47ukG1GYhzlNw8
sesictrl install LICENSE Generic Karma-Render 20.0 100 25-dec-2030 *.*.*.* localhost 2efd0312 5bPGxbraexNWBLONvhXiI8Mfo55oBqgaa0nKjc62AIlHZLTSCiAhpU2OwtCtH7BVJQERipp6+z3X8C
sesictrl install LICENSE Generic Houdini-Render-Script 20.0 100 25-dec-2030 *.*.*.* localhost 0ecbed1b Wt8W@gOsf45bd3loCgI52gJBUY5mx4FJGrV6xvBJjHGeWz+LooEJkmZcJllFQJ8fN+hp8u5UUNQde6
sesictrl install LICENSE Generic Houdini-Render-Plus 20.0 100 25-dec-2030 *.*.*.* localhost 2b2da9f0 1xaLjJMybylexBSI0k9rrEXgd@ypIVP5hmijhRAUgjaJ6Blh3SHZdPZG9nIuITfOKtT@qC2W5jZS60
sesictrl install LICENSE Generic Houdini 20.0 100 25-dec-2030 *.*.*.* localhost 0f679f11 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8V6IZHBdwuTp8@T1iEAUWGAsHA5T@HQ19w8rezZ5
sesictrl install LICENSE Generic Houdini-NG 20.0 100 25-dec-2030 *.*.*.* localhost 7a9ee052 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8ygKd3bZKaYnIMABSWUk7jyKIZZH+gMMoKH4XFPC
sesictrl install LICENSE Generic Render 20.0 100 25-dec-2030 *.*.*.* localhost 72a84fdb HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8+xxmTUI23Dl3O+MvKKE2I2FH+vff3yKF1lDalv2
sesictrl install LICENSE Generic PlayStation 20.0 100 25-dec-2030 *.*.*.* localhost 774dc8b0 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV89Vl32C2x8Z2a9ZKPC1FUVXJyyuQ8NWklFt67JwE
sesictrl install LICENSE Generic Beta 20.0 100 25-dec-2030 *.*.*.* localhost 3b473ed1 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8Gh68lhd2lSjQJOOPRIQb0hvjglA@PYUAX+vDcV8
sesictrl install LICENSE Generic Houdini-ST 20.0 100 25-dec-2030 *.*.*.* localhost b6be4e92 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV85kQ3Ip7pE52wcnKBaHv+6ypqNVlRf8Wf8wjuerC
sesictrl install LICENSE Generic Houdini-Master-Experimental 20.0 100 25-dec-2030 *.*.*.* localhost a688b09b HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8B+D@OrnZrwtvgxlRR5@Uk9OjHJ7lWEjFjw+roN8
sesictrl install LICENSE Generic Render-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost 836d6770 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8CtoDiwZ2GRm9HLThjW7U020Q75Dd6yAX8AZLvBA
sesictrl install LICENSE Generic Houdini-Render-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost e6a76191 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8crf1fnCqc2QLGUT30JOPiAh@nroFO4DW7Wsm6i7
sesictrl install LICENSE Generic Houdini-Master-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost 815e2fd2 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8kBIDMGxyrEHL0x5ilBWlDwqeuYcnDJ0E4uE9Gj6
sesictrl install LICENSE Generic Houdini-Halo-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost eb69115b HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV82mpCLM7HSrtwDX9kIIvrY3VaQJNwcuykL7kgxT7
sesictrl install LICENSE Generic Houdini-Escape-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost d08c8630 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8yzQya81rqOALZzSyWN5jO4fzw@hYWt+qFowOoG2
sesictrl install LICENSE Generic Houdini-Select-NonCommercial 20.0 100 25-dec-2030 *.*.*.* localhost 92868351 HY2FNhCo02WZaJQPy9+5hZvwhQl2dDRmx6jlTV8JQEYAvFvXmxkKyERTP2WHCqh4iHWt8ZJqIrGLw9

echo -e "[main]\nserver = $HQUEUE_SERVER_IP\nport = $HQUEUE_SERVER_PORT\n[job_environment]" > /houdini/hqueue_client/hqnode.ini

# Start the log monitoring script in the background
bash /scripts/cloud_write_monitor.sh &

cd /

# Instead of exec "$@", you can try to run:
exec "$@"
EOF

cat <<'EOF' >/scripts/log_monitor.sh
#!/bin/bash

log_path="/houdini/hqueue_client/hqnode.log"
touch "$log_path"  # Ensure the log file exists

function kill_container(){
	kill -s SIGKILL $(ps -a | awk '{print $1}' | grep -v PID | sort -n | head -1)
}

function prepare_container_shutdown(){
	bash /scripts/compress_files.sh
	kill_container
}

declare -A running_jobs

(sleep 5 && [ "${NO_JOB_KILL:-1}" = "1" ] && echo "No jobs detected. Exiting docker instance." && kill_container) &
timer_pid=$!

echo "TODO TODO TODO !!! Add failed abandoned etc. job cases to automatic container exit, and add a custom job script just in case."

tail -n0 -F "$log_path" | while read -r line; do
    if [[ "$line" =~ Running\ job\ ([0-9]+) ]]; then
    	kill $timer_pid 2>/dev/null
        job_id=${BASH_REMATCH[1]}
        running_jobs["$job_id"]=1
        echo "Detected job start: $job_id"

    elif [[ "$line" =~ Finished\ job\ ([0-9]+) ]]; then
    	kill $timer_pid 2>/dev/null
        job_id=${BASH_REMATCH[1]}
        if [[ ${running_jobs[$job_id]} ]]; then
            echo "Detected job finish: $job_id"
            unset running_jobs["$job_id"]

            # Wait for new jobs within a 5-second window
            end_time=$(( $(date +%s) + 5 ))
            new_job_detected=false

            while [[ $(date +%s) -le $end_time ]]; do
                if read -t 1 line; then
                    if [[ "$line" =~ Running\ job\ ([0-9]+) ]]; then
                        new_job_id=${BASH_REMATCH[1]}
                        if [[ -z ${running_jobs[$new_job_id]} ]]; then
                            echo "Detected new job start: $new_job_id"
                            running_jobs["$new_job_id"]=1
                            new_job_detected=true
                            break
                        fi
                    fi
                fi
            done

            if [[ $new_job_detected == false ]]; then
                echo "No new job detected. Preparing to exit..."
                prepare_container_shutdown
                exit 0
            fi
        fi

    elif [[ "$line" =~ Cancelling\ job\ ([0-9])+ ]]; then
    	job_id={$BASH_REMATCH[1]}
    	if [[ ${running_jobs[$job_id]} ]]; then
    		unset running_jobs[$job_id]
    		echo "Detected job cancelling: $job_id. Preparing to exit..."
    		prepare_container_shutdown
    	fi
    fi
done
EOF
