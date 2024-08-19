import hou
from pathlib import Path
import argparse


def get_parents(child_node: hou.Node):
    parents = []

    input_nodes = child_node.inputs()

    if input_nodes:
        for node in input_nodes:
            parents.append(node)

            parents.extend(get_parents(node))

    return parents


def get_files(base_path, hip_path, node_path):
    try:

        hou.hipFile.load(hip_path)

        node = hou.node(node_path)

        all_parents = get_parents(node)

        files = set()

        for node in all_parents:
            for parm in node.parms():
                if parm.parmTemplate().type() == hou.parmTemplateType.String:
                    file_path = parm.evalAsString()
                    # exists and has string and is a file on local system:
                    if file_path and base_path in file_path and Path(file_path).is_file():
                        files.add(file_path)

        print(files)

        return

    except Exception as e:
        print(f"Exception in hython_script: {e}")

    return


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Hython node file dependency finder')
    parser.add_argument('--base-path', required=True, help='Path of base projects folder to compare paths to')
    parser.add_argument('--hip-path', required=True, help='Location of the hip file')
    parser.add_argument('--node-path', required=True, help='Absolute path of the node in the hip file')
    args = parser.parse_args()

    get_files(
        args.base_path,
        args.hip_path,
        args.node_path
    )
