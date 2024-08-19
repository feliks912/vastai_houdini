import hou
from pathlib import Path


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

        return files if files else None

    except Exception as e:
        print(f"Exception in hython_script: {e}")

    return None
