
local basePath = "C:\\Repos\\DCS\\Spearhead\\classes\\"

assert(loadfile(basePath .. "spearhead_base.lua"))()
assert(loadfile(basePath .. "spearhead_routeutil.lua"))()
assert(loadfile(basePath .. "spearhead_events.lua"))()
assert(loadfile(basePath .. "spearhead_db.lua"))()

assert(loadfile(basePath .. "fleetClasses\\FleetGroup.lua"))()
assert(loadfile(basePath .. "fleetClasses\\GlobalFleetManager.lua"))()

assert(loadfile(basePath .. "configuration\\CapConfig.lua"))()
assert(loadfile(basePath .. "configuration\\CasConfig.lua"))()
assert(loadfile(basePath .. "configuration\\StageConfig.lua"))()

assert(loadfile(basePath .. "stageClasses\\GlobalStageManager.lua"))()
assert(loadfile(basePath .. "stageClasses\\Mission.lua"))()
assert(loadfile(basePath .. "stageClasses\\Stage.lua"))()

assert(loadfile(basePath .. "airClasses\\AttackGroup.lua"))()
assert(loadfile(basePath .. "airClasses\\CapGroup.lua"))()
assert(loadfile(basePath .. "airClasses\\GlobalAirManager.lua"))()
assert(loadfile(basePath .. "airClasses\\RedAirbase.lua"))()
assert(loadfile(basePath .. "airClasses\\SharedAirHelpers.lua"))()

