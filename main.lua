
local dbLogger = Spearhead.LoggerTemplate:new("database", Spearhead.LoggerTemplate.LogLevelOptions.INFO)
local databaseManager = Spearhead.DB:new(dbLogger)

local capConfig = {
    maxDeviationRange = 32186, --20NM -- sets max deviation before flight starts pulling back,
    minSpeed = 400,
    maxSpeed = 500,
    minAlt = 18000,
    maxAlt = 28000,
    minDurationOnStation = 1800,
    maxDurationOnStation = 2700,
    rearmDelay = 600,
    deathDelay = 1800,
    logLevel  = Spearhead.LoggerTemplate.LogLevelOptions.INFO
}

local stageConfig = {
    logLevel = Spearhead.LoggerTemplate.LogLevelOptions.INFO
}

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

