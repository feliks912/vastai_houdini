#!/bin/bash

log_path="/houdini/hqueue_client/hqnode.log"
touch "$log_path"  # Ensure the log file exists

stty sane

: "${NO_JOB_KILL:=1}"
: "${FIRST_JOB_CHECK_TIME:=10}"
: "${NEXT_JOB_CHECK_TIME:=5}"

function destroy_instance(){

  container_id=${VAST_CONTAINERLABEL//[!0-9]/}

  set -a; source /repo/docker/.env; set +a

	if [ "$STOP_NO_TERMINATE" = "1" ]; then
    echo "Files uploaded to cloud. Stopping."
    vastai stop instance "$container_id" --retry 5 --api-key "$VASTAI_API_KEY"
  else
    echo "Files uploaded to cloud. Terminating."
    vastai destroy instance "$container_id" --retry 5 --api-key "$VASTAI_API_KEY"
  fi
}

function prepare_container_shutdown(){
	bash /repo/docker/compress_files.sh
	destroy_instance
}

declare -A running_jobs

(sleep "$FIRST_JOB_CHECK_TIME" && [ "${NO_JOB_KILL:-1}" = "1" ] && echo "No jobs detected. Exiting docker instance." && destroy_instance) &
timer_pid=$!

echo "Current jobs in the job log file:"
cat "$log_path"

stty sane

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
