from vastai import VastAI

def get_id_for_drive(output):
    lines = output.strip().split('\n')
    # Start from line 2 to skip headers
    for line in lines[2:]:
        parts = line.split()
        if len(parts) >= 3:  # Ensure there are enough parts in the line
            cloud_type = parts[-1]
            if cloud_type == 'drive':
                return parts[0]  # Return the ID

vast_sdk = VastAI(api_key="07ae20534a8516741e4110d29027160dce0a057f0549a3cae1908012a56fecc9")

print(get_id_for_drive(vast_sdk.show_connections()))