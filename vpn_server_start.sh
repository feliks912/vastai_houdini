#!/bin/bash

# Function to display the usage of the script
usage() {
    echo "Usage: $0 <HQSERVER_INI_PATH> <SERVER_PORT> <VASTAI_SEARCH_QUERY_PATH>"
    echo "Arguments:"
    echo "  HQSERVER_INI_PATH         Path to the hqserver.ini file"
    echo "  SERVER_PORT               Port number for the HQ server"
    echo "  VASTAI_SEARCH_QUERY_PATH  Path to the VastAI search query file"
    exit 1
}

# Check if the correct number of arguments is passed
if [ "$#" -ne 3 ]; then
    usage
fi

# Assign positional parameters to variables
HQSERVER_INI_PATH="$1"
SERVER_PORT="$2"
QUERY_PATH="$3"

# Ensure the script is run with sudo if not already root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please restart with sudo."
    exit 1
fi

echo "Script is running as: $(whoami), which should be root."

bash /opt/hqueue/scripts/hqserverd stop

# Update the server configuration
sed -i -E "s/^(port = )[0-9]+/\1$SERVER_PORT/" "$HQSERVER_INI_PATH"
echo "Updated port number in $HQSERVER_INI_PATH to $SERVER_PORT."

# Prepare the network namespace name
NETNS_NAME="hqserverd_ns"

# Start vopono and wait for it to be fully ready
echo "Starting vopono and setting up network namespace..."
vopono exec --custom ./AirVPN_Europe_UDP-443-Entry3.ovpn --custom-netns-name "$NETNS_NAME" \
    --protocol openvpn --keep-alive -f "$SERVER_PORT" \
    "bash -c 'sudo bash /opt/hqueue/scripts/hqserverd force-reload || echo Force reload failed, continuing anyway...'" > vopono.log 2>&1 &

# Capture PID of vopono process
vopono_job_id=$!
echo "vopono process started with PID: $vopono_job_id"
# Clean up
trap 'echo "Stopping vopono..."; kill -SIGINT $vopono_job_id' EXIT

# Wait for a message indicating that the vopono is ready
tail -f vopono.log | while read LINE; do
    echo "$LINE"
    if [[ "$LINE" == *"Keep-alive flag active"* ]]; then
        pkill -P $$ tail
        break
    fi
done

# Poll for the public IP address
PUBLIC_IP=""
while true; do
    if ip netns exec "$NETNS_NAME" curl -s ifconfig.me > /dev/null 2>&1; then
        PUBLIC_IP=$(ip netns exec "$NETNS_NAME" curl -s ifconfig.me)
        break
    else
        echo "Waiting for network namespace $NETNS_NAME to be active..."
        sleep 1
    fi
done

echo "Public IP: $PUBLIC_IP, Port: $SERVER_PORT"

# Function to perform tasks as the original user
source /home/feliks/miniconda3/bin/activate base

echo "This is the key: $VASTAI_API_KEY"

    # Run the Python script as the original user
python3 /opt/houdini_scripts/hqserver_handler.py --server-ip "$PUBLIC_IP" --server-port "$SERVER_PORT" --query-file "$QUERY_PATH"

wait $vopono_job_id
