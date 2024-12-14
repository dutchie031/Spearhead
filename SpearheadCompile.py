import os
import sys
import glob
import datetime

def compileClasses(classesPath):
    resultString = ""
    for name in glob.glob(f"{classesPath}/**/*.lua", recursive=True):
        with open(name, 'r') as file:
            part = f"do --{ os.path.basename(name)}\n"
            part += file.read()
            part += f"\nend --{ os.path.basename(name)}\n"
            resultString += part
    return resultString

def compile(root, target):
    classPath = os.path.join(root, "classes")
    classes = compileClasses(classPath)

    dateTime = f"""--[[
        Spearhead Compile Time: {datetime.datetime.now().isoformat()}
    ]]"""

    compiled = f"{dateTime}\n"
    compiled += classes
    
    mainFileName = os.path.join(root, "main.lua")
    with open(mainFileName, 'r') as mainFile: 
        compiled += "do --Main"
        string = mainFile.read()
        compiled += string
        compiled += "end --Main"

    apiFileName = os.path.join(root, "api" , "SpearheadApi.lua")
    with open(apiFile, 'r') as apiFile: 
        string = apiFile.read()
        compiled += "do --Spearhead API"
        compiled += string
        compiled += "end --Spearhead API"

    with open(target, "w") as targetFile:
        targetFile.write(compiled)


if __name__ == "__main__" : 
    args = sys.argv[1:]
    root = args[0]
    target = args[1]

    print(f"Source: {root}")
    print(f"target: {target}")

    compile(root, target)