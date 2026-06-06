--Single player purpose

local Logger                = require("classes.util.Logger")
local DcsUtil               = require("classes.util.DcsUtil")
local Database              = require("classes.spearhead_db")
local SpearheadEvents       = require("classes.spearhead_events")
local MissionCommandsHelper = require("classes.stageClasses.helpers.MissionCommandsHelper")
local CapConfig             = require("classes.configuration.CapConfig")
local StageConfig           = require("classes.configuration.StageConfig")
local Persistence           = require("classes.persistence.Persistence")
local SpawnManager          = require("classes.helpers.SpawnManager")
local DetectionManager      = require("classes.capClasses.detection.DetectionManager")
local GlobalCapManager         = require("classes.capClasses.GlobalCapManager")
local GlobalStageManager       = require("classes.stageClasses.GlobalStageManager")
local GlobalFleetManager       = require("classes.fleetClasses.GlobalFleetManager")
local MissionEditorWarnings = require("classes.util.MissionEditorWarnings")

local defaultLogLevel = "INFO"

if SpearheadConfig and SpearheadConfig.debugEnabled == true then
    defaultLogLevel = "DEBUG"
end

local startTime = timer.getTime() * 1000

SpearheadEvents.Init(defaultLogLevel)

local dbLogger = Logger.new("database", defaultLogLevel)
local standardLogger = Logger.new("", defaultLogLevel)
local databaseManager = Database.New(dbLogger)
MissionCommandsHelper.getOrCreate(defaultLogLevel) -- initiate

local capConfig = CapConfig:new();
local stageConfig = StageConfig:new();

local startingStage = stageConfig.startingStage or 1
if SpearheadConfig and SpearheadConfig.Persistence and SpearheadConfig.Persistence.enabled == true then
    standardLogger:info("Persistence enabled")
    local persistenceLogger = Logger.new("Persistence", defaultLogLevel)
    Persistence.Init(persistenceLogger)

    local persistanceStage = Persistence.GetActiveStage()
    if persistanceStage then
        standardLogger:info("Persistance activated and using persistant active stage: " .. persistanceStage)
        startingStage = persistanceStage
    end
else
    standardLogger:info("Persistence disabled")
end

local spawnLogger = Logger.new("SpawnManager", defaultLogLevel)
local spawnManager = SpawnManager.new(spawnLogger)
local detectionLogger = Logger.new("DetectionManager", defaultLogLevel)
local detectionManager = DetectionManager.New(detectionLogger)

GlobalCapManager.start(databaseManager, capConfig, detectionManager, stageConfig, defaultLogLevel, spawnManager)
GlobalStageManager.NewAndStart(databaseManager, stageConfig, defaultLogLevel, spawnManager)
GlobalFleetManager.start(databaseManager)

local SetStageDelayed = function(number, time)
    SpearheadEvents.PublishStageNumberChanged(number)
    return nil
end

timer.scheduleFunction(SetStageDelayed, startingStage, timer.getTime() + 3)

env.info(startTime .. "ms / " .. timer.getTime() * 1000 .. "ms")
local duration = (timer.getTime() * 1000) - startTime
standardLogger:info("Spearhead Initialisation duration: " .. tostring(duration) .. "ms")

local missionEditorWarningsLogger = Logger.new("MissionEditorWarnings", defaultLogLevel)
MissionEditorWarnings.WriteAll(missionEditorWarningsLogger)
GlobalStageManager:printFullOverview()

--Check lines of code in directory per file:
-- Get-ChildItem . -Include *.lua -Recurse | foreach {""+(Get-Content $_).Count + " => " + $_.name }; GCI . -Include *.lua* -Recurse | foreach{(GC $_).Count} | measure-object -sum |  % Sum
-- find . -name '*.lua' | xargs wc -l

--- ==================== DEBUG ORDER OR ZONE VEC ===========================
-- local zone = Spearhead.DcsUtil.getZoneByName("MISSIONSTAGE_99")

-- local count  = Spearhead.Util.tableLength(zone.verts)

-- for i = 1, count - 1 do

--     local a = zone.verts[i]
--     local b = zone.verts[i+1]

--     local color = {0,0,0,1}

--     color[i] = 1

--     trigger.action.textToAll(-1,  46+i , { x= a.x, y = 0, z = a.z } , color, {0,0,0}, 24 , true , "" .. i )
--     trigger.action.lineToAll(-1 , 56+i , { x= a.x, y = 0, z = a.z } ,  { x = b.x, y = 0, z = b.z } , color , 1, true)

-- end
