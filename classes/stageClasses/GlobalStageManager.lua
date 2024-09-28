

local StagesByName = {}


GlobalStageManager = {}
GlobalStageManager.start = function (database, stageConfig)

    for _, stageName in pairs(database:getStagezoneNames()) do

        local logger = Spearhead.LoggerTemplate:new(stageName, stageConfig.logLevel)
        local stage = Spearhead.internal.Stage:new(stageName, database, logger)

        StagesByName[stageName]  = stage

        local logger = Spearhead.LoggerTemplate:new("StageManager", stageConfig.logLevel)
        logger:info("Initiated " .. Spearhead.Util.tableLength(StagesByName) .. " airbases for cap")

    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalStageManager = GlobalStageManager
