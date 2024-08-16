#!/bin/bash

# Function to kill processes
kill_processes() {
    if [ "$#" -eq 0 ]; then
        echo "No processes to kill."
        return 0
    fi

    for pid in "$@"; do
        if [ -z "$pid" ]; then
            echo "Empty PID skipped."
            continue
        fi
        if ps -p "$pid" > /dev/null; then
            echo "Killing process $pid..."
            if kill -SIGTERM "$pid"; then
                echo "Process $pid killed successfully."
            else
                echo "Failed to kill process $pid."
            fi
        else
            echo "Process $pid already terminated or does not exist."
        fi
    done
}

# Assign positional parameters to variables
USER="$1"
HQSERVER_INI_PATH="$2"
HQSERVER_PORT="$3"
NETDATA_PORT="$4"
QUERY_PATH="$5"
VPN_SERVER="$6"

echo "Script is running as: $(whoami), which should be root."




# Start the Netdata process
nsname="hou_vast"
ns_script="start_servers.sh $HQSERVER_PORT $HQSERVER_INI_PATH $NETDATA_PORT"

echo "Starting servers with namespace '$nsname' on port $HQSERVER_PORT and $NETDATA_PORT, using script $ns_script..."
bash ./vopono_exec.sh "$USER" "$VPN_SERVER" "$nsname" "$HQSERVER_PORT" "$NETDATA_PORT" "$ns_script"

return_code=$?

if [[ $return_code -eq 1 ]]; then
    echo "Error: servers start failed with return code $return_code."
    exit 1
fi

pid=$return_code  # Only correct if return_code was meant to be a PID, adjust as necessary
pids+=("$pid")

# Handle script exit or interruption
trap 'echo "Script exited or interrupted. Stopping Vopono namespaces."; kill_processes "${pids[@]}"; echo "Vopono processes killed."' EXIT SIGINT SIGTERM


# :=================================================D #




# Retrieve and display IP addresses and ports
server_ip=$(cat /tmp/${nsname}_ns_ip.log | awk '{print $2}')
echo "Public server IP: $server_ip"

echo "Checking connection..."
if nc -zv "$server_ip" "$HQSERVER_PORT"; then
    echo "Success: $server_ip is reachable on port $HQSERVER_PORT."
    if nc -zv "$server_ip" "$NETDATA_PORT"; then
      echo "Success: $server_ip is reachable on port $NETDATA_PORT."
    else
      echo "Error: $server_ip is not reachable on port $NETDATA_PORT."
      exit 2
    fi
else
    echo "Error: $server_ip is not reachable on port $HQSERVER_PORT."
    exit 2
fi


# Prompt user to start the server
source /home/feliks/miniconda3/bin/activate base

echo "This is the VASTAI API key: $VASTAI_API_KEY"

while true; do
    echo "Do you want to start the server? [Y/n]"
    read -r -p "Enter your choice: " response
    case "$response" in
        [yY][eE][sS]|[yY]|'')  # Accept yes, YES, y, Y, or empty (return)
            break
            ;;
        [nN][oO]|[nN])         # Accept no, NO, n, N
            echo "Server start canceled."
            exit
            ;;
        *)                      # Handle any other input
            echo "Invalid response. Please enter Y or N."
            ;;
    esac
done

# Run the Python script as the original user
echo "Running Python script as user '$USER'."
su - "$USER" -c "python3 $(pwd)/hqserver_handler.py \
      --server-ip $server_ip \
      --hqserver-port $HQSERVER_PORT \
      --netdata-port $NETDATA_PORT \
      --query-file $QUERY_PATH"

# Wait for all background jobs to finish
wait
