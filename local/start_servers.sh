#!/bin/bash

# Display usage information
usage() {
    echo "Usage: $0 <HQSERVER_PORT> <HQSERVER_INI_PATH> <NETDATA_PORT>"
    echo
    echo "Updates the port number in the specified HQSERVER configuration file and reloads the HQueue server."
    echo
    echo "Arguments:"
    echo "  <HQSERVER_PORT>     The port number to set in the configuration file."
    echo "  <HQSERVER_INI_PATH> The path to the HQSERVER configuration file."
    echo "  <NETDATA_PORT>      The port for the netdata server"
    echo
    echo "Example:"
    echo "  $0 49042 /opt/hqueue/hqserver.ini"
}

# Check if the script is executed with exactly two arguments
if [ "$#" -ne 3 ]; then
    echo "Error: Invalid number of arguments."
    usage
    exit 1
fi

# Assign arguments to variables
HQSERVER_PORT=$1
HQSERVER_INI_PATH=$2
NETDATA_PORT=$3

# Check if the provided port is a valid number (non-negative integer)
if ! [[ "$HQSERVER_PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: HQSERVER_PORT must be a non-negative integer."
    usage
    exit 1
fi

# Check if the specified configuration file exists
if [ ! -f "$HQSERVER_INI_PATH" ]; then
    echo "Error: Configuration file '$HQSERVER_INI_PATH' does not exist."
    exit 1
fi

if ! [[ "$NETDATA_PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: NETDATA_PORT must be a non-negative integer."
    usage
    exit 1
fi

# Update the port number in the configuration file
sed -i -E "s/^(port = )[0-9]+/\1$HQSERVER_PORT/" "$HQSERVER_INI_PATH"

# Reload the HQueue server and handle errors
bash /opt/hqueue/scripts/hqserverd force-reload | tee /tmp/hqserver_start_log.log > /dev/null || {
    echo "Force reload failed, continuing anyway..."
}

# Start Netdata on the specified port
service netdata stop

bash /opt/netdata/bin/netdata -p "$NETDATA_PORT" | tee /tmp/netdata_start_log.log > /dev/null || {
    echo "Netdata start failed, continuing anyway..."
}


echo "Start servers script executed successfully."
