


--assert(loadfile("C:\\Repos\\DCS\\Spearhead\\dev\\dev_classes.lua"))()

local basePath = "C:\\Repos\\DCS\\Spearhead\\"
local classPath = basePath .. "classes\\"

assert(loadfile(classPath .. "spearhead_base.lua"))()
assert(loadfile(classPath .. "spearhead_routeutil.lua"))()
assert(loadfile(classPath .. "spearhead_events.lua"))()
assert(loadfile(classPath .. "spearhead_db.lua"))()

assert(loadfile(classPath .. "fleetClasses\\FleetGroup.lua"))()
assert(loadfile(classPath .. "fleetClasses\\GlobalFleetManager.lua"))()

assert(loadfile(classPath .. "configuration\\CapConfig.lua"))()
assert(loadfile(classPath .. "configuration\\StageConfig.lua"))()

assert(loadfile(classPath .. "stageClasses\\GlobalStageManager.lua"))()
assert(loadfile(classPath .. "stageClasses\\Missions\\Mission.lua"))()

assert(loadfile(classPath .. "stageClasses\\Stages\\Stage.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stages\\PrimaryStage.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stages\\ExtraStage.lua"))()


assert(loadfile(classPath .. "stageClasses\\Groups\\SpearheadGroup.lua"))()

assert(loadfile(classPath .. "stageClasses\\helpers\\MissionCommandsHelper.lua"))()

assert(loadfile(classPath .. "stageClasses\\SpecialZones\\StageBase.lua"))()
assert(loadfile(classPath .. "stageClasses\\SpecialZones\\BlueSam.lua"))()

assert(loadfile(classPath .. "capClasses\\CapGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\GlobalCapManager.lua"))()
assert(loadfile(classPath .. "capClasses\\CapAirbase.lua"))()

assert(loadfile(classPath .. "persistence\\Persistence.lua"))()

-- Startup: 



assert(loadfile(basePath .. "main.lua"))()

