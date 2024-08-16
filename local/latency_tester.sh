#!/bin/bash

# Set HOME from the first script argument
HOME="$1"

# Define the directory where the .ovpn files are stored
VPNDIR="$HOME/.config/vopono/air/openvpn"

# List of European country codes in VPN server names
european_countries="at be bg ch cy cz de dk ee es fi fr gr hr hu ie it lt lu lv mt nl no pl pt ro se si sk"

# Output file for sorted servers by latency
output_sorted="sorted_servers.txt"

# Prepare a list of server IPs
server_ips=$(mktemp)

# Loop through each .ovpn file in the directory
for vpnfile in $VPNDIR/*.ovpn; do
    filename=$(basename "$vpnfile" .ovpn)

    # Check if the server is European by comparing the prefix against the country codes
    if [[ $european_countries =~ ${filename:0:2} ]]; then
        # Extract the server IP from the config file
        server_ip=$(grep "remote " "$vpnfile" | head -1 | awk '{print $2}')

        # Check if server_ip is empty or not
        if [[ ! -z "$server_ip" ]]; then
            echo "$server_ip $filename" >> "$server_ips"
        fi
    fi
done

# Use xargs to run ping in parallel and sort the results by latency
cat "$server_ips" | xargs -P 12 -I {} bash -c '{
    ip=$(echo "{}" | cut -d" " -f1);
    name=$(echo "{}" | cut -d" " -f2);
    latency=$(ping -c 4 $ip | tail -1 | awk -F"/" "{print \$5}");
    echo "Server $name latency: $latency ms" >&2;
    echo "$latency $name";
}' | sort -n -k1 > "$output_sorted"

# Clean up
rm "$server_ips"
echo "Servers sorted by latency and saved to $output_sorted"
