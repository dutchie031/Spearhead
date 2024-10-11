
local dbLogger = Spearhead.LoggerTemplate:new("database", Spearhead.LoggerTemplate.LogLevelOptions.INFO)
local databaseManager = Spearhead.DB:new(dbLogger)

local capConfig = Spearhead.internal.configuration.CapConfig:new();
local stageConfig = Spearhead.internal.configuration.StageConfig:new();

Spearhead.internal.GlobalCapManager.start(databaseManager, capConfig, stageConfig)
Spearhead.internal.GlobalStageManager.start(databaseManager, stageConfig)
Spearhead.internal.GlobalFleetManager.start(databaseManager)

local SetStageDelayed = function(number, time)
    Spearhead.Events.PublishStageNumberChanged(number)
    return nil
end

timer.scheduleFunction(SetStageDelayed, 1, timer.getTime() + 3)

Spearhead.LoadingDone()
--Check lines of code in directory per file: 
-- Get-ChildItem . -Include *.lua -Recurse | foreach {""+(Get-Content $_).Count + " => " + $_.name }; && GCI . -Include *.lua* -Recurse | foreach{(GC $_).Count} | measure-object -sum |  % Sum  
-- find . -name '*.lua' | xargs wc -l

