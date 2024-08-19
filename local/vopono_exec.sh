#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <USER> <SERVER_NAME> <NS_NAME> <HQSERVER_PORT> <NETDATA_PORT> <SCRIPT_PATH>"
    echo
    echo "Arguments:"
    echo "  USER         The name of the user which has vopono ovpn files"
    echo "  SERVER_NAME  The server the vpn will attempt to use."
    echo "  NAME         The base name for the network namespace and log file."
    echo "  HQSERVER_PORT  The port number to be used by hqserver."
    echo "  NETDATA_PORT   The port number used by netdata."
    echo "  SCRIPT_PATH  Path to the custom script to run within Vopono."
    exit 1
}

# Check if the correct number of arguments is passed
if [ "$#" -ne 6 ]; then
    usage >&2
fi

# Assign positional parameters to variables
user="$1"
VPN_SERVER_NAME="$2"
name="$3"
hqserver_port="$4"
netdata_port="$5"
script_path="$6"

# Define network namespace name and log file path
netns_name="${name}_ns"
log_file="/tmp/${netns_name}_log.log"

echo "Checking vopono ip netns list for '$netns_name'" >&2

if ip netns list | grep -q "$netns_name"; then
  ip netns delete "$netns_name"
  sleep 2  # Give some time for the deletion to propagate
  if ip netns list | grep -q "$netns_name"; then
    echo "Failed to delete namespace $netns_name" >&2
    exit 1
  fi
fi

echo "Checking vopono ip link list for '$netns_name'" >&2

if ip link show | grep -q "${netns_name}_d"; then
  ip link delete "${netns_name}_d"
  sleep 2
  if ip link show | grep -q "${netns_name}_d"; then
    echo "Failed to delete ip link $netns_name" >&2
    exit 1
  fi
fi

echo "Starting Vopono with custom command in network namespace '$netns_name'... on server '$VPN_SERVER_NAME'" >&2

# Start Vopono with the given custom command and log to the file
  #since this runs in as a background task, vopono job id will immediately get the
vopono exec --custom-netns-name "$netns_name" \
    --protocol openvpn --custom "/home/$user/.config/vopono/air/openvpn/${VPN_SERVER_NAME}.ovpn" \
    --keep-alive -f "$hqserver_port" -f "$netdata_port" \
    "sudo bash $script_path > /tmp/vopono_script.log" 2>&1 | tee "$log_file" &

vopono_job_id=$!

# Trap signals and ensure that Vopono process is killed upon exit
trap 'kill -s SIGTERM $vopono_job_id' EXIT SIGINT SIGTERM

echo "Vopono process started with PID: $vopono_job_id in namespace '$netns_name'" >&2

# Wait for the log file to be created
while [[ ! -f "$log_file" ]]; do
    echo "Waiting for log file '$log_file' to be created..." >&2
    sleep 1
done

checkjob(){
  if ! ps -p "$1" > /dev/null; then
      echo "$(tput setaf 1)Vopono process has stopped, exiting vopono_exec script$(tput sgr0)" >&2
      trap - EXIT SIGINT SIGTERM
      exit 1
  fi
}

# Monitor the log file for specific messages
if ! tail -f "$log_file" | while read -r LINE; do
    checkjob $vopono_job_id

    if [[ "$LINE" == *"Keep-alive flag active"* ]]; then
        echo "Keep-alive flag detected, exiting tail loop." >&2
        pkill -P $$ tail
        break
    elif [[ "$LINE" == *"Shutting down vopono"* ]]; then
        pkill -P $$ tail
        echo "Vopono shutting down. Killing tail!" >&2
        exit 1
    fi
done; then
  exit 1
fi

echo "Exited tail loop" >&2

# Verify network namespace status
echo "Checking network namespace status with 'ip netns list'" >&2
ip netns list >&2

# Poll for the public IP address
while true; do
    # Exit if Vopono process is no longer running
    checkjob $vopono_job_id

    echo "Attempting to fetch public IP address..." >&2
    public_ip=$(ip netns exec "$netns_name" curl -s ifconfig.me)
    echo "Attempted to fetch public IP address!" >&2
    if [[ -n "$public_ip" ]]; then
        echo "Public IP found: $public_ip" >&2
        echo "$netns_name $public_ip" > "/tmp/${netns_name}_ip.log"
        break
    else
        echo "No public IP retrieved, trying again..." >&2
        sleep 1
    fi
done

echo "Returning!!!" >&2

# Reset trap settings
trap - EXIT SIGINT SIGTERM

# Output the PID of the Vopono job
echo "$vopono_job_id"
