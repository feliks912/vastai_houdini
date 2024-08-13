#!/bin/bash


# Temporary file that will hold the script
temporary_file="create_files.shh"

# Create or truncate the temporary file
> "$temporary_file"

# Read each .sh file and write commands to the temporary script to recreate these files
for file in *.sh; do
    echo "cat <<'EOF' >$(basename "$file")" >> "$temporary_file"
    cat "$file" >> "$temporary_file"
    echo "EOF" >> "$temporary_file"
    echo "" >> "$temporary_file" # Add a newline for readability between files
done

# Make the temporary script executable
chmod +x "$temporary_file"

echo "Script $temporary_file created. Run it to recreate the .sh files in any directory."
