local GlobalCapManager = {}
do
    local airbasesPerStage = {}
    local allAirbasesByName = {}
    local activeAirbasesPerActiveStage = {}
    local unitsPerzonePerStage = {}

    local initiated = false

    function GlobalCapManager.start(database, capConfig, stageConfig)
        if initiated == true then return end

        local logger = Spearhead.LoggerTemplate:new("AirbaseManager", capConfig.logLevel)

        local zones = database:getStagezoneNames()
        if zones then
            for key, stageName in pairs(zones) do
                if airbasesPerStage[stageName] == nil then
                    airbasesPerStage[stageName] = {}
                end

                local airbaseIds = database:getAirbaseIdsInStage(stageName)
                if airbaseIds then
                    for _, id in pairs(airbaseIds) do
                        local airbaseName = Spearhead.DcsUtil.getAirbaseName(id)
                        if airbaseName then
                            local airbaseSpecificLogger = Spearhead.LoggerTemplate:new("CAP_" .. airbaseName, capConfig.logLevel)
                            local airbase = Spearhead.internal.CapAirbase:new(id, database, airbaseSpecificLogger, capConfig, stageConfig)
                            if airbase then
                                table.insert(airbasesPerStage[stageName], airbase)
                                allAirbasesByName[airbaseName] = airbase
                            end
                        end
                    end
                end
            end
        end

        logger:info("Initiated " .. Spearhead.Util.tableLength(allAirbasesByName) .. " airbases for cap")
        initiated = true

        local InfoFunctions = {}

        ---returns if there is CAP active 
        ---@param zoneName any
        ---@param activeZoneNumber number
        ---@return boolean
        InfoFunctions.IsCapActiveWhenZoneIsActive = function(zoneName, activeZoneNumber)
            for _, airbase in pairs(airbasesPerStage[zoneName]) do
                if airbase:IsBaseActiveWhenStageIsActive(activeZoneNumber) == true then
                    return true
                end
            end
            return false
        end

        Spearhead.capInfo = InfoFunctions
    end
end

Spearhead.internal.GlobalCapManager = GlobalCapManager
