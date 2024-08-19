import time
import xmlrpc.client
import subprocess
import argparse
import datetime
import os
import tarfile
from dotenv import load_dotenv
from tabulate import tabulate
import vastai_instance_handler as vastai_handler
import read_configuration as conf
import base64

from hython.run_hython import run_hython_command


def encode_account_key_from_config(config_path):
    account = None
    key = None
    # Flag to determine if we are within the relevant section
    in_relevant_section = False

    try:
        with open(config_path, 'r') as file:
            for line in file:
                # Check if we are entering the relevant section
                if line.strip() == "[backblaze]":
                    in_relevant_section = True
                elif line.startswith('[') and in_relevant_section:
                    # If we hit another section while we were in the relevant section
                    break
                elif in_relevant_section:
                    # Extract account and key
                    if 'account =' in line:
                        account = line.split('=')[1].strip()
                    elif 'key =' in line:
                        key = line.split('=')[1].strip()

        if account and key:
            # Encode the account and key in Base64 format
            encoded_string = base64.b64encode(f'{account}:{key}'.encode()).decode('utf-8')
            print(f'Base64 encoded account:key string: {encoded_string}')
            return encoded_string
        else:
            print("Account or key not found in the configuration.")
            return None

    except FileNotFoundError:
        print("The specified configuration file does not exist.")
        return None


def get_first_directory(path):
    """Get the first directory from the given path."""
    normalized_path = os.path.normpath(path)
    path_components = [component for component in normalized_path.split(os.sep) if component]
    first_directory = path_components[0] if path_components else None
    print(f"First directory: {first_directory}")
    return first_directory



def get_project_folder_name(hip_file_path, base_path):
    """Get the project folder name from the hip file path."""
    base_path = base_path.rstrip('/') + '/'
    relative_path = hip_file_path.replace(base_path, "")
    project_folder_path = os.path.dirname(relative_path) + "/"
    return project_folder_path


def format_compressed_filename(template, job):
    """Format the compressed file name based on the template and job information."""
    try:
        if template is None:
            raise ValueError("Tar name template undefined.")

        job_id = job['id']
        job_name = job['name'].split(' -> ')[1].split(' ')[1].split('/')[-1].split('.')[0]
        job_datetime = datetime.datetime.strptime(job['queueTime'].value, "%Y%m%dT%H:%M:%S")
        job_date = job_datetime.strftime("%Y%m%d")
        job_time = job_datetime.strftime("%H%M%S")
        submitted_by = job['submittedBy']
        tags = "_".join(job['tags'])

        filename = template.replace("%job_id", str(job_id))
        filename = filename.replace("%hip_name", job_name)
        filename = filename.replace("%date", job_date)
        filename = filename.replace("%time", job_time)
        filename = filename.replace("%submitted_by", submitted_by)
        filename = filename.replace("%tags", tags)

        return filename
    except Exception as e:
        print(f"Exception in format compressed filename: {e}")


def main(server_ip, hqserver_port, netdata_port, configuration_file):
    """Main function to monitor jobs, upload files, and manage VastAI instances."""
    env_path = '/opt/houdini_scripts/.env'
    load_dotenv(dotenv_path=env_path)

    api_key = os.getenv("VASTAI_API_KEY")
    if not api_key:
        raise Exception("VASTAI_API_KEY not found in the .env file. Please ensure it is defined.")

    print(f"The key is {api_key}")
    print(f"Python script server IP: {server_ip}, server port: {hqserver_port}")

    hq = xmlrpc.client.ServerProxy(f"http://{server_ip}:{hqserver_port}")

    safety_flag = False

    while True:
        try:
            queued_jobs = hq.getJobIdsByStatus(["queued"])
            if len(queued_jobs) == 1:
                _, env_vars, local_vars = conf.read_configuration(configuration_file)

                job_id = queued_jobs[0]
                job = hq.getJob(job_id)
                print(job)

                job_children = job['children']
                for child in job_children:
                    print(hq.getJob(child))

                local_project_path = local_vars.get('LOCAL_PROJECTS_PATH')
                hip_file_path = job['name'].split(' HIP: ')[1].split(' ')[0]
                trailing_project_folder = hip_file_path.replace(local_project_path.rstrip("/") + "/", "")
                rclone_gcloud_name = local_vars.get("RCLONE_GCLOUD_NAME")
                gcloud_projects_folder = local_vars.get("GCLOUD_ROOT_PROJECTS_FOLDER")

                print("Uploading latest HIP file to the cloud")

                child_hip_location = os.path.join(*trailing_project_folder.split('/')[:-1])

                rclone_upload_hip_to = os.path.join(gcloud_projects_folder.strip('/'), child_hip_location)

                upload_command = (
                        f"rclone copy -vv "
                        f"--config ./rclone.conf "
                        f"{hip_file_path} {rclone_gcloud_name}:{rclone_upload_hip_to}"
                )

                subprocess.run(upload_command, shell=True)
                print(f"Uploading {hip_file_path} to {rclone_gcloud_name}:{rclone_upload_hip_to}")

                project_root_folder_name = get_project_folder_name(hip_file_path, local_project_path)
                compressed_file_name = format_compressed_filename(env_vars.get('COMPRESSED_FILE_NAME_TEMPLATE'), job)

                files_to_download = run_hython_command(
                    local_vars.get('HOUDINI_PATH'),
                    local_project_path,
                    hip_file_path,
                    job['name'].split(' ROP: ')[1]
                )

                fileset = set()

                fileset.add(trailing_project_folder)  # Add the hip file to the download list

                if files_to_download and len(files_to_download) > 0:
                    for file_path in files_to_download:
                        file_path = str(file_path).replace(local_project_path.rstrip("/") + "/", "")
                        fileset.add(file_path)

                print("Files to download:")
                for file_path in fileset:
                    print(file_path)

                if not safety_flag:
                    success, contract_id = vastai_handler.create_vast_ai_instance(
                        fileset,
                        compressed_file_name,
                        project_root_folder_name,
                        server_ip,
                        hqserver_port,
                        netdata_port,
                        configuration_file
                    )
                    if not success:
                        raise Exception("VastAI instance creator returned with a failed code.")
                    if not contract_id:
                        raise Exception("Create VastAI instance failed in returning a valid contract ID.")
                    safety_flag = True

                print("The instance is booting, we're waiting for the job to begin...")

                while True:
                    parent_status = hq.getJob(job_id, ["status"])['status']
                    children_statuses = [{'id': id, 'status': hq.getJob(id, ["status"])['status']} for id in job_children]

                    print(f"Parent ID {job_id} status: {parent_status}")
                    for child_status in children_statuses:
                        print(f"Child ID {child_status['id']} status: {child_status['status']}")

                    instances, _ = vastai_handler.get_instances()
                    instance = next((i for i in instances if str(contract_id) in i), None)

                    if not instance:
                        print("No rented instances exist. Likely a port issue.")
                    elif "loading" in instance:
                        print("Instance is loading")
                    elif "running" in instance:
                        all_clients = hq.getClients()

                        try:
                            keys = ["available", "cpus", "cpuSpeed", "id", "ip", "lastHeartbeat", "load", "memory", "memoryInUse", "runningJobs"]

                            job_client = next(
                                (client for client in all_clients if job_id in client['runningJobs'] or
                                 any(child_id in client['runningJobs'] for child_id in job['children'])),
                                None
                            )

                            if job_client:
                                filtered_client = {key: job_client[key] for key in keys if key in job_client}
                                print(tabulate([filtered_client], headers="keys", tablefmt="grid"))
                            else:
                                print("No clients found on the job, even if instances are running")
                        except Exception as e:
                            import traceback
                            print(f"Exception in client listing: {type(e).__name__}, {e}")
                            traceback.print_exc()
                            return 1

                    if parent_status in ("failed", "cancelled", "abandoned"):
                        print("Job failed, cancelled, or abandoned. Destroying all instances.")
                        vastai_handler.destroy_all_instances()
                        safety_flag = False
                        break
                    elif parent_status == "succeeded":
                        print("Simulation or render succeeded. Congratulations!")

                        print(f"Scanning for compressed file on {rclone_gcloud_name}")
                        command = f"rclone ls --config ./rclone.conf {rclone_gcloud_name}:{gcloud_projects_folder} \
                                | grep {compressed_file_name}"
                        while True:
                            result = subprocess.run(command, shell=True, text=True, stdout=subprocess.PIPE)
                            if result.stdout.strip():
                                print("File found. Destroying all instances.")
                                break
                            else:
                                print("File not yet present")
                                time.sleep(1)

                        vastai_handler.destroy_all_instances()

                        authstring = encode_account_key_from_config('./rclone.conf')

                        download_command = (
                            f"rclone copy -vv "
                            f"--config ./rclone.conf "
                            f"--header 'workerauth:Basic {authstring}' "
                            f"--b2-download-url https://01042010.xyz "
                            f"{rclone_gcloud_name}:{os.path.join(gcloud_projects_folder, compressed_file_name)} "
                            f"{local_project_path}"
                        )

                        subprocess.run(download_command, shell=True)
                        print(f"Downloading {compressed_file_name} to {local_project_path}")

                        print("File downloaded. Extracting...")
                        tar_path = os.path.join(local_project_path, compressed_file_name)

                        with tarfile.open(tar_path, "r:gz") as tar_ref:
                            tar_ref.extractall(local_project_path)
                        print("File extracted.")
                        os.remove(tar_path)
                        print("File removed successfully.")
                        print("JOB DONE")

                        safety_flag = False
                        break

                    time.sleep(3)

            elif len(queued_jobs) > 1:
                print("Multiple queued jobs found")
            else:
                print("No queued jobs found")
                time.sleep(5)
        except ConnectionRefusedError:
            print("HQueue server is not available")
            break
        except Exception as e:
            import traceback
            print(f"An error occurred in HQueue server handler: {type(e).__name__}, {e}")
            traceback.print_exc()
            return 1


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    main("213.152.186.173", 49042, 49043, "./configuration.conf")

    parser = argparse.ArgumentParser(description='HQueue Job Monitor and VastAI Instance Creation Script')
    parser.add_argument('--server-ip', required=True, help='Public server IP address')
    parser.add_argument('--hqserver-port', required=True, help='Server port for HQueue')
    parser.add_argument('--netdata-port', required=True, help='Port of NetData server')
    parser.add_argument('--query-file', required=True, help='Path to the VastAI search query file')
    args = parser.parse_args()

    main(
        args.server_ip,
        args.hqserver_port,
        args.netdata_port,
        args.query_file
    )
