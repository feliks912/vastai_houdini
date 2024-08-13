#!/bin/bash

log_path="/houdini/hqueue_client/hqnode.log"
touch "$log_path"  # Ensure the log file exists

: "${NO_JOB_KILL:=1}"
: "${FIRST_JOB_CHECK_TIME:=10}"
: "${NEXT_JOB_CHECK_TIME:=5}"

function kill_container(){
	kill -s SIGKILL "$(ps -a | awk '{print $1}' | grep -v PID | sort -n | head -1)"
}

function prepare_container_shutdown(){
	bash /scripts/compress_files.sh
	kill_container
}

declare -A running_jobs

(sleep "$FIRST_JOB_CHECK_TIME" && [ "${NO_JOB_KILL:-1}" = "1" ] && echo "No jobs detected. Exiting docker instance." && kill_container) &
timer_pid=$!

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
            unset 'running_jobs["$job_id"]'

            # Wait for new jobs within a 5-second window
            end_time=$(( $(date +%s) + "$NEXT_JOB_CHECK_TIME" ))
            new_job_detected=false

            while [[ $(date +%s) -le $end_time ]]; do
                if read -r -t 1 line; then
                    if [[ "$line" =~ Running\ job\ ([0-9]+) ]]; then
                        new_job_id="${BASH_REMATCH[1]}"
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
    	job_id="${BASH_REMATCH[1]}"
    	if [[ ${running_jobs[$job_id]} ]]; then
    		unset 'running_jobs[$job_id]'
    		echo "Detected job cancelling: $job_id. Preparing to exit..."
    		prepare_container_shutdown
    	fi
    fi
done
