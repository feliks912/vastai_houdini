#!/bin/bash

# Environment variable names for the encrypted key and data
ENCRYPTED_KEY="$ENCRYPTED_KEY_ENV"
ENCRYPTED_DATA="$ENCRYPTED_DATA_ENV"

# Path to the RSA private key within the Docker container
PRIVATE_KEY_PATH="/root/private.pem"

# Output file path for the decrypted configuration
DECRYPTED_CONFIG_PATH="/root/.config/rclone/rclone.conf"

# Decode the encrypted AES key from Base64 and decrypt it


# Check if the AES key was successfully decrypted
if ! DECRYPTED_AES_KEY="$(echo "$ENCRYPTED_KEY" | base64 --decode | openssl rsautl -decrypt -inkey $PRIVATE_KEY_PATH)"; then
    echo "Failed to decrypt AES key."
    exit 1
fi

# Check if the configuration was successfully decrypted
if ! echo "$ENCRYPTED_DATA" | base64 --decode | openssl enc -aes-256-cfb8 -d -K "$DECRYPTED_AES_KEY" > $DECRYPTED_CONFIG_PATH; then
    echo "Decryption successful. Configuration is ready."
    # Optionally, you can start rclone or any other service now
    rclone listremotes --config $DECRYPTED_CONFIG_PATH
else
    echo "Failed to decrypt configuration."
fi

# Keep the container running or execute specific tasks
bash
