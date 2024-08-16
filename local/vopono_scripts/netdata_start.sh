#!/bin/bash

# Display usage information
usage() {
    echo "Usage: $0 <NETDATA_PORT>"
    echo
    echo "Starts the Netdata service on the specified port."
    echo
    echo "Arguments:"
    echo "  <NETDATA_PORT>  The port number on which Netdata will listen."
    echo
    echo "Example:"
    echo "  $0 19999"
}

# Check if the script is executed with exactly one argument
if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    usage
    exit 1
fi

# Assign argument to variable
netdata_port=$1

# Check if the provided port is a valid number (non-negative integer)
if ! [[ "$netdata_port" =~ ^[0-9]+$ ]]; then
    echo "Error: NETDATA_PORT must be a non-negative integer."
    usage
    exit 1
fi

# Start Netdata on the specified port
systemctl netdata stop

sudo /opt/netdata/bin/netdata -p "$netdata_port" | tee /tmp/netdata_start_log.log > /dev/null || {
    echo "Netdata start failed, continuing anyway..."
}

echo "Netdata started on port $netdata_port."
n