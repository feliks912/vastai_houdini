#!/bin/bash

usage() {
    echo "Usage: $0 <USER> <HQSERVER_INI_PATH> <HQSERVER_PORT> <NETDATA_PORT> <QUERY_PATH>"
    echo
    echo "Arguments:"
    echo "  USER                  User to run the rclone binary with."
    echo "  HQSERVER_INI_PATH     Path to the HQ server configuration file."
    echo "  HQSERVER_PORT         Port number for the HQ server."
    echo "  NETDATA_PORT          Port number for the Netdata service."
    echo "  QUERY_PATH            Path to the VastAI search query file."
    echo
    echo "Example:"
    echo "  $0 feliks /opt/hqueue/hqserver.ini 49042 49043 search_query.txt"
    exit 1
}

# Check if the correct number of arguments is passed
if [ "$#" -ne 5 ]; then
    usage
fi

USER="$1"
HQSERVER_INI_PATH="$2"
HQSERVER_PORT="$3"
NETDATA_PORT="$4"
QUERY_PATH="$5"

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

org_retries=3
retries=$org_retries

while [[ retries -ne 0 ]]
do
  bash ./vpn_server.sh "$USER" "$HQSERVER_INI_PATH" "$HQSERVER_PORT" "$NETDATA_PORT" "$QUERY_PATH"
  return_code=$?
  if [[ return_code -eq 0 ]]; then
    echo "vpn_server exited successfuly. Exiting."
    exit 0
  elif [[ return_code -eq 1 ]]; then
    echo "vpn_server encountered an error, exiting start.sh"
    exit 1
  elif [[ return_code -eq 2 ]]; then
    echo "opened ports not available, retrying."
    retries=$((retries-1))
  fi
done

echo "retried $org_retries times. Exiting."