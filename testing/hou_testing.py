from pathlib import Path
import hou

def get_parents(child_node: hou.Node):
    parents = []

    input_nodes = child_node.inputs()

    if input_nodes:
        for input in input_nodes:
            parents.append(input)

            parents.extend(get_parents(input))

    return parents

hou.hipFile.load("/media/feliks/Data/houdini/houdini_projects/20.0/fluids_lesson_start/wineglass_01.hip")

node:hou.Node = hou.node("/obj/wine_fluid/retime1")

parms = node.parms()

for parm in parms:
    parm:hou.Parm = parm.name()
    print(parm)

quit()
all_parents = get_parents(node)

files = set()

for node in all_parents:
    for parm in node.parms():
        if parm.parmTemplate().type() == hou.parmTemplateType.String:
            file_path = parm.evalAsString()
            # exists and has string and is a file on local system:
            if file_path and "/fluids_lesson_start" in file_path and Path(file_path).is_file():
                 files.add(file_path)

print(files)