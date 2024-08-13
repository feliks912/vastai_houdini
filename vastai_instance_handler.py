import os
import time
from vastai import VastAI
from dotenv import load_dotenv
import json
import argparse
import re
import read_configuration as conf
import datetime
import base64


def extract_disk_space(configuration_file_path):
    """Extract the disk_space value from the search query template."""
    try:
        with open(configuration_file_path, 'r') as file:
            lines = file.readlines()
            disk_space = None
            for line in lines:  # Correct usage
                if line.startswith("disk_space"):
                    # Use regex to find the last number in the line
                    match = re.search(r'\d+$', line)
                    if match:
                        disk_space = int(match.group(0))
                        break

            if disk_space is None:
                raise ValueError("disk_space not defined in the search query file.")
            return disk_space
    except Exception as e:
        print(f"Exception in extract_disk_space: {e}")


def destroy_all_instances():
    """Destroy all VastAI instances"""
    # Load API key from environment variable
    try:
        api_key = os.getenv('VASTAI_API_KEY')

        vast_sdk = VastAI(api_key=api_key)

        instances = vast_sdk.show_instances(quiet=True).split('\n')

        instances = [instance for instance in instances if instance]

        int_list = [int(x) for x in instances if x != '']

        print(vast_sdk.destroy_instances(ids=int_list))

        return 1
    except Exception as e:
        print(f"Exception in destroy_all_instances: {e}")


def upload_to_cloud(contract_id, source_folder, dest_folder):
    try:
        api_key = os.getenv('VASTAI_API_KEY')

        vast_sdk = VastAI(api_key=api_key)

        vast_sdk.cloud_copy(
            src=source_folder,  # /houdini_projects/*
            dst=dest_folder,
            # /rclone_mint/houdini_projects/
            instance=contract_id,
            connection=get_id_for_drive(vast_sdk.show_connections()),
            transfer="Cloud To Instance"
        )
        print("Uploading data to cloud")

        return 1
    except Exception as e:
        print(f"Exception in transfer_to_cloud: {e}")


def format_compressed_filename(template, job):
    # Extracting values from the job object
    job_id = job['id']
    job_name = job['name'].split(' -> ')[1].split(' ')[1].split('/')[-1].split('.')[
        0]  # Simplistic parsing to extract 'wineglass_01'
    job_datetime = datetime.datetime.strptime(job['queueTime'].value, "%Y%m%dT%H:%M:%S")
    job_date = job_datetime.strftime("%Y%m%d")  # Now includes hours, minutes, and seconds
    job_time = job_datetime.strftime("%H%M%S")
    submitted_by = job['submittedBy']
    tags = "_".join(job['tags'])  # Join all tags with underscores

    # Replace placeholders in the template
    filename = template.replace("%job_id", str(job_id))
    filename = filename.replace("%hip_name", job_name)
    filename = filename.replace("%date", job_date)
    filename = filename.replace("%time", job_time)
    filename = filename.replace("%submitted_by", submitted_by)
    filename = filename.replace("%tags", tags)

    return filename


def get_id_for_drive(output):
    lines = output.strip().split('\n')
    # Start from line 2 to skip headers
    for line in lines[2:]:
        parts = line.split()
        if len(parts) >= 3:  # Ensure there are enough parts in the line
            cloud_type = parts[-1]
            if cloud_type == 'drive':
                return parts[0]  # Return the ID


def stop_all_instances():
    """Stop all VastAI instances"""
    # Load API key from environment variable
    try:
        api_key = os.getenv('VASTAI_API_KEY')

        vast_sdk = VastAI(api_key=api_key)

        instances = vast_sdk.show_instances(quiet=True).split('\n')

        instances = [instance for instance in instances if instance]

        int_list = [int(x) for x in instances if x != '']

        print(vast_sdk.stop_instances(IDs=int_list))

        return 1
    except Exception as e:
        print(f"Exception in stop_all_instances: {e}")


def create_vast_ai_instance(job, project_folder_name, server_ip, server_port, configuration_file_path):
    """Create a VastAI instance based on the provided search query file."""
    # Load API key from environment variable
    api_key = os.getenv('VASTAI_API_KEY')

    vast_sdk = VastAI(api_key=api_key)

    try:
        search_query, env_vars, local_variables = conf.read_configuration(configuration_file_path)

        if not search_query or not env_vars or not local_variables:
            raise ValueError("No search query or environment or local variables defined.")

        # Extract the disk_space vdisk_space = extract_disk_space(configuration_file)
        disk_space = extract_disk_space(configuration_file_path)

    except ValueError as e:
        print(f"Exception when reading search query files: {e}")
        return 1

    print(f"Search configuration string:\n{search_query}")

    try:
        # Generate environment string dynamically
        compressed_file_name_template = env_vars.pop('COMPRESSED_FILE_NAME_TEMPLATE',
                                                     None)  # Remove this as it needs special handling

        if compressed_file_name_template is None:
            raise ValueError("No compressed file name template defined.")
        # Check if the template exists, and generate the filename accordingly
        if compressed_file_name_template:
            compressed_file_name = format_compressed_filename(compressed_file_name_template, job)
        else:
            compressed_file_name = "new_project_files.tar.gz"
        env_vars['COMPRESSED_FILE_NAME'] = compressed_file_name  # Add this dynamically created filename to env_vars
        # Generate full environment string for Docker
        env_string = ' '.join(f"-e {key}={value}" for key, value in env_vars.items())

        with open(local_variables.get("RCLONE_CONFIG_LOCATION"), 'r') as file:
            base64_rconfig_conf = base64.b64encode(file.read().encode('ascii')).decode('ascii')

        env_string += f" -e RCLONE_BASE64_ENCRYPTED={base64_rconfig_conf}"

        print("Environment String:\n", env_string)

    except ValueError as e:
        print(e)
        return 1

    try:
        search_offers = vast_sdk.search_offers(
            limit=1,
            storage=disk_space,
            order='dph',
            query=search_query  # Use the formatted query
        )

        response_lines = search_offers.split('\n')

        if len(response_lines) > 1:
            offer_id = int(response_lines[1].split()[0])
            print(f"Selected Offer ID: {offer_id}")

            response = vast_sdk.create_instance(
                ID=offer_id,
                disk=disk_space,  # Use extracted disk space from configurations
                image="feliks912/houdini20.0_ubuntu20.04:latest",
                env=f"-e HQUEUE_SERVER_IP={server_ip} -e HQUEUE_SERVER_PORT={server_port} {env_string}",
                onstart_cmd='env >> /etc/environment;',
                cancel_unavail=True,
                ssh=True
            )

            json_response = json.loads(response[response.rfind('{'):]
                                       .replace("'", '"')
                                       .replace("True", "true")
                                       .replace("False", "false"))

            if json_response['success']:

                instance_id = json_response['new_contract']

                while str(instance_id) not in vast_sdk.show_instance(id=instance_id):
                    time.sleep(1)

                while not [line for line in vast_sdk.show_instance(id=instance_id).splitlines() if "running" in line]:
                    time.sleep(1)

                source = "/" + str(local_variables.get('GCLOUD_PROJECTS_FOLDER')).strip('/') + "/" + str(
                    project_folder_name).strip('/')
                destination = "/" + str(local_variables.get("LOCAL_PROJECTS_PATH")).strip('/') + "/" + str(
                    project_folder_name).strip('/')
                instance_id = str(json_response['new_contract'])
                connection = get_id_for_drive(vast_sdk.show_connections())

                # Download project from the cloud
                try:
                    vast_sdk.cloud_copy(
                        src=source,
                        dst=destination,
                        instance=instance_id,
                        connection=connection,
                        transfer="Cloud To Instance"
                    )
                    print("Cloud to Instance copy commenced.")

                except Exception as e:
                    print(f"Copy operation Cloud to Instance failed with exception: {e}")

                print("Instance created successfully with contract ID:", json_response['new_contract'])
                return (
                    True,
                    json_response['new_contract'],
                    env_vars.get("COMPRESSED_FILE_NAME")
                )
            else:
                return False, None, None
        else:
            print("No instances offered for those requirements")
            return False, None, None
    except Exception as e:
        print(f"An error occurred in vastai instance handler: {e}")
        return False, None, None


if __name__ == "__main__":
    # Argument parsing
    parser = argparse.ArgumentParser(description='VastAI Instance Handler Script')
    parser.add_argument('--server-ip', required=True, help='Server IP address')
    parser.add_argument('--server-port', required=True, help='Server port')
    parser.add_argument('--query-file', required=True, help='Path to the search query file')
    args = parser.parse_args()

    # Call the function with the provided arguments
    create_vast_ai_instance(args.server_ip, args.server_port, args.query_file)
