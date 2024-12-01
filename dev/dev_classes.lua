

local basePath = "C:\\Repos\\DCS\\Spearhead\\classes\\"

assert(loadfile(basePath .. "config.lua"))()

assert(loadfile(basePath .. "spearhead_base.lua"))()
assert(loadfile(basePath .. "spearhead_routeutil.lua"))()
assert(loadfile(basePath .. "spearhead_events.lua"))()
assert(loadfile(basePath .. "spearhead_db.lua"))()

assert(loadfile(basePath .. "fleetClasses\\FleetGroup.lua"))()
assert(loadfile(basePath .. "fleetClasses\\GlobalFleetManager.lua"))()

assert(loadfile(basePath .. "configuration\\CapConfig.lua"))()
assert(loadfile(basePath .. "configuration\\StageConfig.lua"))()

assert(loadfile(basePath .. "stageClasses\\GlobalStageManager.lua"))()
assert(loadfile(basePath .. "stageClasses\\Mission.lua"))()
assert(loadfile(basePath .. "stageClasses\\Stage.lua"))()

assert(loadfile(basePath .. "capClasses\\CapGroup.lua"))()
assert(loadfile(basePath .. "capClasses\\GlobalCapManager.lua"))()
assert(loadfile(basePath .. "capClasses\\CapAirbase.lua"))()

-- Startup: 

assert(loadfile(basePath .. "main.lua"))()