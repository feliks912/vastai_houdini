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

echo "Script is running as: $(whoami), which should be root."

# Start the HQ server process
hqserver_nsname="hqserver"
hqserver_script="vopono_scripts/hqserver_start.sh $HQSERVER_PORT $HQSERVER_INI_PATH"

echo "Starting HQ server with namespace '$hqserver_nsname' on port $HQSERVER_PORT using script $hqserver_script..."

sudo ./vopono_exec.sh "$hqserver_nsname" "$HQSERVER_PORT" "$hqserver_script"
return_code=$?

if [[ $return_code -eq 1 ]]; then
    echo "Error: HQ server start failed with return code $return_code."
    exit 1
fi

pid=$return_code  # Only correct if return_code was meant to be a PID, adjust as necessary
pids+=("$pid")
# Handle script exit or interruption
trap 'echo "Script exited or interrupted. Stopping Vopono namespaces."; kill_processes "${pids[@]}"; echo "Vopono processes killed."' EXIT SIGINT SIGTERM


# :=================================================D #

# Start the Netdata process
netdata_nsname="netdata"
netdata_script="vopono_scripts/netdata_start.sh $NETDATA_PORT"

echo "Starting Netdata with namespace '$netdata_nsname' on port $NETDATA_PORT using script $netdata_script..."
sudo ./vopono_exec.sh "$netdata_nsname" "$NETDATA_PORT" "$netdata_script"
return_code=$?

if [[ $return_code -eq 1 ]]; then
    echo "Error: Netdata start failed with return code $return_code."
    exit 1
fi

pid=$return_code  # Only correct if return_code was meant to be a PID, adjust as necessary
pids+=("$pid")

# Handle script exit or interruption
trap 'echo "Script exited or interrupted. Stopping Vopono namespaces."; kill_processes "${pids[@]}"; echo "Vopono processes killed."' EXIT SIGINT SIGTERM




# Retrieve and display IP addresses and ports
hqserver_ip_port=$(cat /tmp/${hqserver_nsname}_ns_ip_port.log)
hqserver_ip=$(echo "$hqserver_ip_port" | awk '{print $2}')
hqserver_port=$(echo "$hqserver_ip_port" | awk '{print $3}')
echo "HQ server Public IP: $hqserver_ip, HQ server Port: $hqserver_port"

echo "Checking connection..."
if nc -zv "$hqserver_ip" "$hqserver_port"; then
    echo "Success: $hqserver_ip is reachable on port $hqserver_port."
else
    echo "Error: $hqserver_ip is not reachable on port $hqserver_port."
    exit 2
fi



netdata_ip_port=$(cat /tmp/${netdata_nsname}_ns_ip_port.log)
netdata_ip=$(echo "$netdata_ip_port" | awk '{print $2}')
netdata_port=$(echo "$netdata_ip_port" | awk '{print $3}')
echo "Netdata Public IP: $netdata_ip, Netdata Port: $netdata_port"

echo "Checking connection..."
if nc -zv "$netdata_ip" "$netdata_port"; then
    echo "Success: $netdata_ip is reachable on port $netdata_port."
else
    echo "Error: $netdata_ip is not reachable on port $netdata_port."
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
      --netdata-ip $netdata_ip \
      --netdata-port $NETDATA_PORT \
      --hqserver-ip $hqserver_ip \
      --hqserver-port $hqserver_port \
      --query-file $QUERY_PATH"

# Wait for all background jobs to finish
wait
