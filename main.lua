
--Single player purpose

local debug = false
local id = net.get_my_player_id()
if id == 0 then
    debug = true
end

local dbLogger = Spearhead.LoggerTemplate:new("database", Spearhead.LoggerTemplate.LogLevelOptions.INFO)
local standardLogger = Spearhead.LoggerTemplate:new("", Spearhead.LoggerTemplate.LogLevelOptions.INFO)
local databaseManager = Spearhead.DB:new(dbLogger, debug)

local capConfig = Spearhead.internal.configuration.CapConfig:new();
local stageConfig = Spearhead.internal.configuration.StageConfig:new();

standardLogger:info("Using StageConfig: ".. stageConfig:toString())


Spearhead.internal.GlobalCapManager.start(databaseManager, capConfig, stageConfig)
Spearhead.internal.GlobalStageManager:NewAndStart(databaseManager, stageConfig)
Spearhead.internal.GlobalFleetManager.start(databaseManager)

local SetStageDelayed = function(number, time)
    Spearhead.Events.PublishStageNumberChanged(number)
    return nil
end

local startingStage = stageConfig:getStartingStage() or 1

timer.scheduleFunction(SetStageDelayed, startingStage, timer.getTime() + 3)

Spearhead.LoadingDone()
--Check lines of code in directory per file: 
-- Get-ChildItem . -Include *.lua -Recurse | foreach {""+(Get-Content $_).Count + " => " + $_.name }; && GCI . -Include *.lua* -Recurse | foreach{(GC $_).Count} | measure-object -sum |  % Sum  
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

