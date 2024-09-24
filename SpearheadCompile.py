import os
import sys
import glob

Order = [
    "spearhead_defaults.lua",
    "spearhead_base.lua",
    "spearhead_events.lua",
    "spearhead_dcsbase.lua",
    "spearhead_routes.lua",
    "spearhead_mission.lua",
    "spearhead_db.lua",
    "spearhead_stage.lua",
    "spearhead_cap.lua",
    "spearhead.lua"
]

def compile(root, target):
    compiled = ""
    for filename in Order:
        path = os.path.join(root, filename)
        with open(path,'r') as file:
            fileContents = file.read()
            compiled += fileContents
        print(path)

    with open(target, "w") as targetFile:
        targetFile.write(compiled)
    

if __name__ == "__main__" : 
    args = sys.argv[1:]
    root = args[0]
    target = args[1]

    print(f"Source: {root}")
    print(f"target: {target}")

    compile(root, target)