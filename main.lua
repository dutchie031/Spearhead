--Single player purpose

local defaultLogLevel = "INFO"

if SpearheadConfig and SpearheadConfig.debugEnabled == true then
    defaultLogLevel = "DEBUG"
end

local startTime = timer.getTime() * 1000

Spearhead.Events.Init(defaultLogLevel)

local dbLogger = Spearhead.LoggerTemplate.new("database", defaultLogLevel)
local standardLogger = Spearhead.LoggerTemplate.new("", defaultLogLevel)
local databaseManager = Spearhead.DB.New(dbLogger)
Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(defaultLogLevel) -- initiate

local capConfig = Spearhead.internal.configuration.CapConfig:new();
local stageConfig = Spearhead.internal.configuration.StageConfig:new();

local startingStage = stageConfig.startingStage or 1
if SpearheadConfig and SpearheadConfig.Persistence and SpearheadConfig.Persistence.enabled == true then
    standardLogger:info("Persistence enabled")
    local persistenceLogger = Spearhead.LoggerTemplate.new("Persistence", defaultLogLevel)
    Spearhead.classes.persistence.Persistence.Init(persistenceLogger)

    local persistanceStage = Spearhead.classes.persistence.Persistence.GetActiveStage()
    if persistanceStage then
        standardLogger:info("Persistance activated and using persistant active stage: " .. persistanceStage)
        startingStage = persistanceStage
    end
else
    standardLogger:info("Persistence disabled")
end

local spawnLogger = Spearhead.LoggerTemplate.new("SpawnManager", defaultLogLevel)
local spawnManager = Spearhead.classes.helpers.SpawnManager.new(spawnLogger)
local detectionLogger = Spearhead.LoggerTemplate.new("DetectionManager", defaultLogLevel)
local detectionManager = Spearhead.classes.capClasses.detection.DetectionManager.New(detectionLogger)

Spearhead.classes.capClasses.GlobalCapManager.start(databaseManager, capConfig, detectionManager, stageConfig, defaultLogLevel, spawnManager)
Spearhead.internal.GlobalStageManager:NewAndStart(databaseManager, stageConfig, defaultLogLevel, spawnManager)

Spearhead.internal.GlobalFleetManager.start(databaseManager)

local SetStageDelayed = function(number, time)
    Spearhead.Events.PublishStageNumberChanged(number)
    return nil
end

timer.scheduleFunction(SetStageDelayed, startingStage, timer.getTime() + 3)

env.info(startTime .. "ms / " .. timer.getTime() * 1000 .. "ms")
local duration = (timer.getTime() * 1000) - startTime
standardLogger:info("Spearhead Initialisation duration: " .. tostring(duration) .. "ms")

Spearhead.LoadingDone()

Spearhead.internal.GlobalStageManager:printFullOverview()

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
