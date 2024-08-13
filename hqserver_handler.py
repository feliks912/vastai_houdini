import time
import xmlrpc.client
from dotenv import load_dotenv
import subprocess
import argparse
import vastai_instance_handler as vastai_handler
import os
import zipfile
import read_configuration as conf


def get_first_directory(path):
    # Normalize the path to ensure it is in a standard format
    normalized_path = os.path.normpath(path)

    # Split the path into components
    path_components = normalized_path.split(os.sep)

    # Filter out any empty strings in case the path starts with a separator
    path_components = [component for component in path_components if component]

    first_directory = path_components[0] if path_components else None

    print(f"First directory: {first_directory}")

    # Return the first component if it exists, otherwise return None
    return first_directory


def update_job_path(job, local_path, remote_path):
    old_path = job['name'].split(' HIP: ')[1].split(' ')[0]  # Extract the current path
    root_project_folder = old_path.replace(local_path, "")  # Remove base path
    new_path = remote_path + "/" + root_project_folder  # Construct new path
    job['name'] = job['name'].replace(old_path, new_path)  # Replace old path in the job name

    new_job = {'children': job['children'], 'conditions': job['conditions']}

    return new_job, '/'.join(root_project_folder.split('/')[:-1])


def get_project_folder_name(hip_file_path, base_path):
    # Ensure the base path ends with a slash
    base_path = base_path.rstrip('/') + '/'

    # Replace the base path in the hip file path with nothing
    relative_path = hip_file_path.replace(base_path, "")

    # Split the relative path and get all components except the last one (the file name)
    project_folder_path = '/'.join(relative_path.split('/')[:-1])

    return project_folder_path


def main(server_ip, server_port, configuration_file):
    env_path = '/opt/houdini_scripts/.env'
    load_dotenv(dotenv_path=env_path)

    # Check if VASTAI_API_KEY is present
    api_key = os.getenv("VASTAI_API_KEY")
    if not api_key:
        raise Exception("VASTAI_API_KEY not found in the .env file. Please ensure it is defined.")

    print(f"The key is {api_key}")

    print("python script server ip: {server_ip}, server port: {server_port}".format(server_ip=server_ip,
                                                                                    server_port=server_port))
    hq = xmlrpc.client.ServerProxy(
        "http://{server_ip}:{server_port}".format(server_ip=server_ip, server_port=server_port))

    _, env_vars, local_vars = conf.read_configuration(configuration_file)

    safety_flag = False

    while True:
        try:
            queued_jobs = hq.getJobIdsByStatus(["queued"])
            if len(queued_jobs) == 1:
                job_id = queued_jobs[0]

                job = hq.getJob(job_id)
                print(hq.getJob(job_id))

                job_children = job['children']
                for child in job_children:
                    print(hq.getJob(child))

                hip_file_path = job['name'].split(' HIP: ')[1].split(' ')[0]  # full path to local hip file

                local_project_path = local_vars.get('LOCAL_PROJECTS_PATH')

                # Get 'fluids_lesson_start' project folder
                trailing_project_folder = hip_file_path.replace(local_project_path.rstrip("/") + "/",
                                                                "")  # /project_folder_name/.../hip_file.hip

                rclone_gcloud_name = local_vars.get("RCLONE_GCLOUD_NAME")  # gdrive
                gcloud_projects_folder = local_vars.get("GCLOUD_PROJECTS_FOLDER")  # /houdini_projects

                print("Uploading latest hip file to the cloud")

                upload_folder = '/'.join(trailing_project_folder.split('/')[:-1])  #/project_folder_name/.../

                # Upload latest hip file from local to gdrive:/houdini_projects/project_folder_name/.../
                rclone_gcloud_projects_folder = '/'.join(str(gcloud_projects_folder).strip('/').split('/')[1:]) #TODO: Dangit fix this. Assumes rclone is set up to the first layer of folders in gdrive
                upload_command = f"rclone copy {hip_file_path} {rclone_gcloud_name}:{rclone_gcloud_projects_folder}/{upload_folder}"

                subprocess.run(upload_command, shell=True)
                print(f"Uploading {hip_file_path} to {rclone_gcloud_name}:{rclone_gcloud_projects_folder}/{upload_folder}")

                project_folder_name = get_project_folder_name(hip_file_path, local_project_path),

                # Call the instance creation function
                if not safety_flag:
                    success, contract_id, compressed_file_name = vastai_handler.create_vast_ai_instance(
                        job,
                        project_folder_name,  #/project_folder_name
                        server_ip,
                        server_port,
                        configuration_file
                    )
                    if not success:
                        raise Exception("vastai_instance_creator returned with a failed code.")

                    safety_flag = True

                print("The instance is booting, we're waiting for the job to begin...")

                while True:
                    parent_status = hq.getJob(job_id, ["status"])['status']
                    children_statuses = ({'id': id, 'status': hq.getJob(id, ["status"])['status']} for id in
                                         job_children)

                    print(f"Parent id {job_id} status: {parent_status}")

                    for children_status in children_statuses:
                        print(f"Child id {children_status['id']} status: {children_status['status']}")

                    if parent_status in ("failed", "cancelled", "abandoned"):
                        print("job failed, cancelled, or abandoned. Destroying all instances.")
                        vastai_handler.destroy_all_instances()
                        safety_flag = False
                        break

                    elif parent_status == "succeeded":
                        print("LOLOLOLOL Succeeded.")

                        time.sleep(5)

                        print("Stopping all instances")
                        vastai_handler.stop_all_instances()

                        print("intializing upload to cloud")
                        vastai_handler.upload_to_cloud(
                            contract_id,
                            "/" + local_vars.get("LOCAL_PROJECTS_PATH").strip('/') + "/" + str(project_folder_name).strip("/"),  # /media/feliks/.../20.0/*
                            local_vars.get("GCLOUD_PROJECTS_FOLDER") + "/" + project_folder_name,
                            # /rclone_mint/houdini_projects/,
                        )  # -> /rclone_mint/houdini_projects/files

                        print("Scanning for compressed file on gdrive")
                        command = f"rclone ls {rclone_gcloud_name}: | grep {compressed_file_name}"
                        while True:
                            result = subprocess.run(command, shell=True, text=True, stdout=subprocess.PIPE)
                            if result.stdout.strip():
                                print("File found. Destroying all instances.")
                                break
                            else:
                                print("File not yet present")
                                time.sleep(1)

                        vastai_handler.destroy_all_instances()

                        download_command = f"rclone copy {rclone_gcloud_name}:{compressed_file_name} {local_project_path}"
                        subprocess.run(download_command, shell=True)
                        print(f"Downloading {compressed_file_name} to {local_project_path}")

                        print("file downloaded. Extracting")
                        zip_path = os.path.normcase(os.path.join(local_project_path, compressed_file_name))

                        # Extract the file
                        with zipfile.ZipFile(zip_path, "r") as zip_ref:
                            zip_ref.extractall(local_project_path)
                        print("File extracted.")

                        print("DONE")

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
            print(f"An error occurred in hqueue server handler: {e}")
            break


if __name__ == "__main__":
    # Argument parsing
    """
    parser = argparse.ArgumentParser(description='HQueue Job Monitor and VastAI Instance Creation Script')
    parser.add_argument('--server-ip', required=True, help='Server IP address for VastAI')
    parser.add_argument('--server-port', required=True, help='Server port for VastAI')
    parser.add_argument('--query-file', required=True, help='Path to the VastAI search query file')
    args = parser.parse_args()
    

    # Call the main function with the provided arguments
    main(args.server_ip, args.server_port, args.query_file)
    """

    main("213.152.162.149", 49042, "search_query.txt")
