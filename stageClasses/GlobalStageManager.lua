

local StagesByName = {}


GlobalStageManager = {}
GlobalStageManager.start = function (database)

    for _, stageName in pairs(database:getStagezoneNames()) do

        local logger = Spearhead.LoggerTemplate:new(stageName, Spearhead.config.logLevel)
        local stage = Spearhead.internal.Stage:new(stageName, database, logger)

        StagesByName[stageName]  = stage

        local logger = Spearhead.LoggerTemplate:new("StageManager", Spearhead.config.logLevel)
        logger:info("Initiated " .. Spearhead.Util.tableLength(StagesByName) .. " airbases for cap")

    end
end

Spearhead.internal.GlobalStageManager = GlobalStageManager
