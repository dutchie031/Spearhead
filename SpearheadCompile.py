import os
import sys
import glob

def compileClasses(classesPath):
    resultString = ""
    for name in glob.glob(f"{classesPath}/**/*.lua"):
        with open(name, 'r') as file:
            resutlString += file.read()
    return resultString

def compile(root, target):
    classes = compileClasses(root)
    compiled = ""
    compiled += classes
    
    mainFileName = os.path.join(root, "main.lua")
    with open(mainFileName, 'r') as mainFile: 
        string = mainFile.read()
        compiled += string

    with open(target, "w") as targetFile:
        targetFile.write(compiled)


if __name__ == "__main__" : 
    args = sys.argv[1:]
    root = args[0]
    target = args[1]

    print(f"Source: {root}")
    print(f"target: {target}")

    compile(root, target)