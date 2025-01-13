

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
assert(loadfile(classPath .. "stageClasses\\Mission.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stage.lua"))()
assert(loadfile(classPath .. "stageClasses\\StageBase.lua"))()

assert(loadfile(classPath .. "capClasses\\CapGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\GlobalCapManager.lua"))()
assert(loadfile(classPath .. "capClasses\\CapAirbase.lua"))()

assert(loadfile(classPath .. "persistence\\Persistence.lua"))()

-- Startup: 



assert(loadfile(basePath .. "main.lua"))()

