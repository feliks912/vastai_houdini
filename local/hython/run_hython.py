import subprocess
import ast
import os

def run_hython_command(houdini_path, base_path, hip_path, node_path):
    # Define the command to run
    command = (
        f"cd {houdini_path} && "
        f". ./houdini_setup > /dev/null && "
        f"{houdini_path}/bin/hython {os.path.abspath('hython/hython_script.py')} "
        f"--base-path {base_path} "
        f"--hip-path {hip_path} "
        f"--node-path {node_path}"
    )

    # Run the command using subprocess
    try:
        # Capture the output and error if any
        result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, text=True, executable='/bin/bash')

        # Process the output
        if result.stdout.strip():
            # Convert the string output to a set using ast.literal_eval for safety
            file_paths = ast.literal_eval(result.stdout.strip())
            if file_paths:
                print("File paths returned:")
                return file_paths
            else:
                print("No file paths returned.")
        else:
            print("No output from hython command.")

        # Handle errors if any
        if result.stderr:
            print("Error:", result.stderr)

    except subprocess.CalledProcessError as e:
        print("Failed to run hython command:", e)
    except SyntaxError as e:
        print("Error parsing output:", e)
    except Exception as e:
        print("An error occurred:", e)

    return None
