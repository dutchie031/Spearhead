


--assert(loadfile("C:\\Repos\\DCS\\Spearhead\\dev\\dev_classes.lua"))()

local basePath = "C:\\Repos\\DCS\\Spearhead\\"
local classPath = basePath .. "classes\\"

assert(loadfile(classPath .. "_baseClasses\\Queue.lua"))()

assert(loadfile(classPath .. "spearhead_base.lua"))()
assert(loadfile(classPath .. "spearhead_routeutil.lua"))()
assert(loadfile(classPath .. "spearhead_events.lua"))()
assert(loadfile(classPath .. "spearhead_db.lua"))()

assert(loadfile(classPath .. "fleetClasses\\FleetGroup.lua"))()
assert(loadfile(classPath .. "fleetClasses\\GlobalFleetManager.lua"))()

assert(loadfile(classPath .. "configuration\\CapConfig.lua"))()
assert(loadfile(classPath .. "configuration\\StageConfig.lua"))()

assert(loadfile(classPath .. "stageClasses\\GlobalStageManager.lua"))()
assert(loadfile(classPath .. "stageClasses\\missions\\baseMissions\\Mission.lua"))()
assert(loadfile(classPath .. "stageClasses\\missions\\ZoneMission.lua"))()
assert(loadfile(classPath .. "stageClasses\\missions\\RunwayStrikeMission.lua"))()
assert(loadfile(classPath .. "stageClasses\\missions\\BuildableMission.lua"))()


assert(loadfile(classPath .. "stageClasses\\Stages\\BaseStage\\Stage.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stages\\PrimaryStage.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stages\\ExtraStage.lua"))()
assert(loadfile(classPath .. "stageClasses\\Stages\\WaitingStage.lua"))()


assert(loadfile(classPath .. "stageClasses\\Groups\\SpearheadGroup.lua"))()

assert(loadfile(classPath .. "stageClasses\\helpers\\MissionCommandsHelper.lua"))()
assert(loadfile(classPath .. "stageClasses\\helpers\\SupplyConfig.lua"))()
assert(loadfile(classPath .. "stageClasses\\helpers\\SupplyUnitsTracker.lua"))()
assert(loadfile(classPath .. "stageClasses\\helpers\\BattleManager.lua"))()

assert(loadfile(classPath .. "stageClasses\\SpecialZones\\StageBase.lua"))()
assert(loadfile(classPath .. "stageClasses\\SpecialZones\\BlueSam.lua"))()
assert(loadfile(classPath .. "stageClasses\\SpecialZones\\FarpZone.lua"))()
assert(loadfile(classPath .. "stageClasses\\SpecialZones\\SupplyHub.lua"))()

assert(loadfile(classPath .. "capClasses\\taskings\\RTB.lua"))()
assert(loadfile(classPath .. "capClasses\\taskings\\CAP.lua"))()
assert(loadfile(classPath .. "capClasses\\taskings\\SWEEP.lua"))()
assert(loadfile(classPath .. "capClasses\\taskings\\INTERCEPT.lua"))()
assert(loadfile(classPath .. "capClasses\\airGroups\\AirGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\airGroups\\CapGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\airGroups\\SweepGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\airGroups\\InterceptGroup.lua"))()
assert(loadfile(classPath .. "capClasses\\detection\\DetectionManager.lua"))()
assert(loadfile(classPath .. "capClasses\\GlobalCapManager.lua"))()
assert(loadfile(classPath .. "capClasses\\CapAirbase.lua"))()
assert(loadfile(classPath .. "capClasses\\runwayBombing\\RunwayBombingTracker.lua"))()

assert(loadfile(classPath .. "persistence\\Persistence.lua"))()

-- Startup: 



assert(loadfile(basePath .. "main.lua"))()

