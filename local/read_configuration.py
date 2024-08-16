def read_configuration(file_path):
    """Read and parse configuration from a file."""

    def extract_section(lines, start_marker, end_marker):
        """Extract content between start and end markers, ignoring comments."""
        capture = False
        content = []
        for line in lines:
            line = line.strip()
            if start_marker in line:
                capture = True
                continue
            elif end_marker in line:
                capture = False
                break
            if capture:
                # Strip out comments and add non-empty lines
                cleaned_line = line.split('#', 1)[0].strip()
                if cleaned_line:
                    content.append(cleaned_line)
        return content

    def extract_key_value_pairs(lines):
        """Extract key-value pairs from lines, handling quotes properly."""
        key_value_dict = {}
        for line in lines:
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.split('#', 1)[0].strip()  # Remove inline comments
                # Remove surrounding double quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                key_value_dict[key] = value
        return key_value_dict

    # Read and strip lines from the file
    with open(file_path, 'r') as file:
        lines = [line.strip() for line in file]

    # Extract sections based on defined markers
    settings_content = extract_section(lines, "CONT_BEGIN", "CONT_END")
    settings_string = ' '.join(settings_content)

    env_vars_content = extract_section(lines, "ENV_BEGIN", "ENV_END")
    env_vars_dict = extract_key_value_pairs(env_vars_content)

    loc_vars_content = extract_section(lines, "LOC_BEGIN", "LOC_END")
    loc_vars_dict = extract_key_value_pairs(loc_vars_content)

    return settings_string, env_vars_dict, loc_vars_dict
