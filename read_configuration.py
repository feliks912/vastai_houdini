def read_configuration(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()
    
    def extract_section(lines, start_marker, end_marker):
        """Extract content between start and end markers, ignoring comments."""
        capture = False
        content = []
        for line in lines:
            if start_marker in line.strip():
                capture = True
                continue
            elif end_marker in line.strip():
                capture = False
                break
            if capture:
                # Strip out the comment by splitting on '#' and taking the first part
                cleaned_line = line.split('#', 1)[0].strip()
                if cleaned_line:  # Only append if the line is not empty after removing the comment
                    content.append(cleaned_line)
        return content

    def extract_settings(content):
        """Extract settings into a single string."""
        return ' '.join(content)

    def extract_key_value_pairs(content):
        """Extract key-value pairs from content, handling quotes properly."""
        key_value_dict = {}
        for line in content:
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().split('#', 1)[0].strip()  # Remove inline comments
                # Remove surrounding double quotes if present
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                key_value_dict[key] = value
        return key_value_dict

    # Extract sections based on defined markers
    settings_content = extract_section(lines, "CONT_BEGIN", "CONT_END")
    settings_string = extract_settings(settings_content)

    env_vars_content = extract_section(lines, "ENV_BEGIN", "ENV_END")
    env_vars_dict = extract_key_value_pairs(env_vars_content)

    loc_vars_content = extract_section(lines, "LOC_BEGIN", "LOC_END")
    loc_vars_dict = extract_key_value_pairs(loc_vars_content)

    return settings_string, env_vars_dict, loc_vars_dict
