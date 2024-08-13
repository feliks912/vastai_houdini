import hou
try:
    hou.hipFile.load("/media/feliks/Data/houdini/houdini_projects/20.0/fluids_lesson_start/wineglass_01.hip")
except Exception as e:
    print(f"Exception: {e}")

print(hou.Node.node("/out/hq_sim2"))

