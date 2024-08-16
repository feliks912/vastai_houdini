#!/bin/bash

usage() {
    echo "Usage: $0 <USER> <HQSERVER_INI_PATH> <HQSERVER_PORT> <NETDATA_PORT> <QUERY_PATH> <SORTED_SERVERS_LIST>"
    echo
    echo "Arguments:"
    echo "  USER                  User to run the rclone binary with."
    echo "  HQSERVER_INI_PATH     Path to the HQ server configuration file."
    echo "  HQSERVER_PORT         Port number for the HQ server."
    echo "  NETDATA_PORT          Port number for the Netdata service."
    echo "  QUERY_PATH            Path to the VastAI search query file."
    echo "  SORTED_SERVERS_LIST   Path to the sorted list of VPN servers by latency."
    echo
    echo "Example:"
    echo "  $0 feliks /opt/hqueue/hqserver.ini 49042 49043 search_query.txt /path/to/sorted_servers.txt"
    exit 1
}

# Check if the correct number of arguments is passed
if [ "$#" -ne 6 ]; then
    usage
fi

USER="$1"
HQSERVER_INI_PATH="$2"
HQSERVER_PORT="$3"
NETDATA_PORT="$4"
QUERY_PATH="$5"
SORTED_SERVERS_LIST="$6"

# Check if the user exists
if ! id "$USER" &>/dev/null; then
    echo "Error: User '$USER' does not exist."
    exit 1
fi

# Ensure the script is run with sudo if not already root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please restart with sudo."
    exit 1
fi

org_retries=5
retries=$org_retries

# Load top N server names based on the number of retries
mapfile -t servers < <(grep -v '^#' "$SORTED_SERVERS_LIST" | head -n "$retries")

# Attempt to connect to each server in the list
for server in "${servers[@]}"; do
    AIRVPN_SERVER_NAME=$(echo "$server" | awk '{print $2}')  # Assuming the server name is the second field

    echo "Attempting to connect to $AIRVPN_SERVER_NAME..."
    bash ./vpn_server.sh "$USER" "$HQSERVER_INI_PATH" "$HQSERVER_PORT" "$NETDATA_PORT" "$QUERY_PATH" "$AIRVPN_SERVER_NAME"
    return_code=$?

    if [[ $return_code -eq 0 ]]; then
        echo "vpn_server exited successfully. Exiting."
        exit 0
    elif [[ $return_code -eq 1 ]]; then
        echo "vpn_server encountered an error, exiting start.sh"
        exit 1
    elif [[ $return_code -eq 2 ]]; then
        echo "Opened ports not available, retrying with next server."
    fi
done

echo "Tried $org_retries servers. Exiting."
