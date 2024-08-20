import os
import subprocess
import json
import argparse
import re
import base64
from vastai import VastAI
from dotenv import load_dotenv
import read_configuration as conf


def extract_disk_space(configuration_file_path):
    """Extract the disk_space value from the search query template."""
    try:
        with open(configuration_file_path, 'r') as file:
            lines = file.readlines()
            disk_space = None
            for line in lines:
                if line.startswith("disk_space"):
                    match = re.search(r'\d+', line)
                    if match:
                        disk_space = int(match.group())
                        break

            if disk_space is None:
                raise ValueError("disk_space not defined in the search query file.")
            return disk_space
    except Exception as e:
        print(f"Exception in extract_disk_space: {e}")
        return None


def get_instances(ids=False):
    """Retrieve list of instances or their IDs from VastAI."""
    try:
        api_key = os.getenv('VASTAI_API_KEY')
        vast_sdk = VastAI(api_key=api_key)

        instances = vast_sdk.show_instances(quiet=ids).split('\n')

        if ids:
            int_list = [int(x) for x in instances if x]
            return int_list, vast_sdk

        instances = [instance for instance in instances[1:] if instance]
        return instances, vast_sdk

    except Exception as e:
        print(f"Exception in get_instances: {e}")
        return [], None


def destroy_all_instances():
    """Destroy all VastAI instances."""
    try:
        int_list, vast_sdk = get_instances(ids=True)
        if not vast_sdk:
            return 1
        print(vast_sdk.destroy_instances(ids=int_list))
        return 0
    except Exception as e:
        print(f"Exception in destroy_all_instances: {e}")
        return 1


def stop_all_instances():
    """Stop all VastAI instances."""
    try:
        int_list, vast_sdk = get_instances(ids=True)
        if not vast_sdk:
            return 1
        print(vast_sdk.stop_instances(IDs=int_list))
        return 0
    except Exception as e:
        print(f"Exception in stop_all_instances: {e}")
        return 1


def get_id_for_drive(output):
    """Extract the ID for a drive from the output."""
    lines = output.strip().split('\n')
    for line in lines[2:]:
        parts = line.split()
        if len(parts) >= 3:
            cloud_type = parts[-1]
            if cloud_type == 'drive':
                return parts[0]
    return None


def create_vast_ai_instance(
        files_to_download: set[str],
        compressed_file_name: str,
        project_root_folder_name: str,
        server_ip: str,
        hqueue_server_port: str,
        netdata_server_port: str,
        configuration_file_path: str):
    """Create a VastAI instance based on the provided search query file."""
    api_key = os.getenv('VASTAI_API_KEY')
    if not api_key:
        print("VASTAI_API_KEY environment variable not set.")
        return False, None

    vast_sdk = VastAI(api_key=api_key)

    try:
        search_query, env_vars, local_variables = conf.read_configuration(configuration_file_path)

        if not search_query or not env_vars or not local_variables:
            raise ValueError("No search query or environment or local variables defined.")

        # Extract the disk_space
        disk_space = extract_disk_space(configuration_file_path)
        if disk_space is None:
            return False, None

    except ValueError as e:
        print(f"Exception when reading search query files: {e}")
        return False, None

    print(f"Search configuration string:\n{search_query}")

    try:
        env_vars.pop('COMPRESSED_FILE_NAME_TEMPLATE', None)
        git_crypt_key_path = env_vars.pop('GIT_CRYPT_KEY_PATH', None)

        container_vars = env_vars.copy()

        with open(git_crypt_key_path, 'rb') as key:
            binary_key = key.read()
            encoded_key = base64.b64encode(binary_key)
            encoded_key_string = encoded_key.decode('utf-8')

            container_vars.update({'GIT_CRYPT_KEY': f"\"{encoded_key_string}\""})

        # If selective file download is set to true (1) it will employ custom logic I havent' yet defined
        files_to_download = ','.join(files_to_download) if local_variables.get('SELECTIVE_FILE_DOWNLOAD') else ""

        container_vars.update({
            'PROJECT_FOLDER_NAME': f"\"{project_root_folder_name}\"",
            'HOUDINI_PROJECTS_PATH': f"\"{local_variables.get('LOCAL_PROJECTS_PATH')}\"",
            'COMPRESSED_FILE_NAME': f"\"{compressed_file_name}\"",
            'RCLONE_GCLOUD_NAME': f"\"{local_variables.get('RCLONE_GCLOUD_NAME')}\"",
            'GCLOUD_ROOT_PROJECTS_FOLDER': f"\"{local_variables.get('GCLOUD_ROOT_PROJECTS_FOLDER')}\"",
            'FILES_TO_DOWNLOAD': f"\"{files_to_download}\""
        })

        env_string = ' '.join(f"-e {key}={value}" for key, value in container_vars.items())

        print("Environment String:\n", env_string)

    except Exception as e:
        print(f"An error occurred: {e}")

    order = 'dph'
    limit = 1

    try:
        command = (
            f"vastai search offers --storage {disk_space} --limit {limit} "
            f"-o '{order}' "
            f"'{search_query}'"
        )

        response = None
        while True:
            response_lines = subprocess.run(command, capture_output=True, text=True, shell=True).stdout.split('\n')
            response_lines = [line for line in response_lines if line]

            if not response_lines:
                print("No instances offered for those requirements.")
                return False, None

            offer_id = int(response_lines[1].split()[0])
            print(f"Selected Offer ID: {offer_id}")

            try:
                response = vast_sdk.create_instance(
                    ID=offer_id,
                    disk=disk_space,
                    image="feliks912/houdini20.0_cuda12.2:latest",
                    env=f"-p 5001:5001 -e NETDATA_SERVER_IP=\"{server_ip}\" -e NETDATA_SERVER_PORT=\"{netdata_server_port}\" -e HQUEUE_SERVER_IP=\"{server_ip}\" -e HQUEUE_SERVER_PORT=\"{hqueue_server_port}\" {env_string}",
                    onstart_cmd='env >> /etc/environment; echo "setw -g mouse on" > ~/.tmux.conf; /scripts/entrypoint.sh;',
                    cancel_unavail=True,
                    ssh = False
                )
            except Exception as e:
                print(f"Exception when calling create instance: {e}")
                if "404 Client Error: Not Found for url:" in str(e):
                    continue
                else:
                    return False, None

            break

        if response is None:
            print("No exception but response is None????")
            return False, None

        json_response = json.loads(response[response.rfind('{'):]
                                   .replace("'", '"')
                                   .replace("True", "true")
                                   .replace("False", "false"))

        if json_response.get('success'):
            print("Instance created successfully with contract ID:", json_response['new_contract'])
            return True, int(json_response['new_contract'])
        else:
            raise Exception("Instance creation JSON response indicated failure.")

    except Exception as e:
        print(f"An error occurred in VastAI instance handler: {e}")
        return False, None


if __name__ == "__main__":
    # Argument parsing
    parser = argparse.ArgumentParser(description='VastAI Instance Handler Script')
    parser.add_argument('--files-to-download', required=True, help="A list of files to download on the container instance before running the job")
    parser.add_argument('--project-root-folder-name', required=True, help='Project root folder name')
    parser.add_argument('--server-ip', required=True, help='Netdata server IP address')
    parser.add_argument('--hqueue-server-port', required=True, help='HQueue server port')
    parser.add_argument('--netdata-server-port', required=True, help='Netdata server port')
    parser.add_argument('--query-file', required=True, help='Path to the search query file')
    parser.add_argument('--compressed-file-name', required=True, help='Name of the compressed file')

    args = parser.parse_args()

    # Call the function with the provided arguments
    create_vast_ai_instance(
        files_to_download=args.files_to_download,
        project_root_folder_name=args.project_root_folder_name,
        server_ip=args.server_ip,
        hqueue_server_port=args.hqueue_server_port,
        netdata_server_port=args.netdata_server_port,
        configuration_file_path=args.query_file,
        compressed_file_name=args.compressed_file_name,
    )
