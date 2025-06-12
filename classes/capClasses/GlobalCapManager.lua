local GlobalCapManager = {}
do
    local airbasesPerStage = {}
    local allAirbasesByName = {}
    local activeAirbasesPerActiveStage = {}
    local unitsPerzonePerStage = {}

    local initiated = false

    ---comment
    ---@param database Database
    ---@param capConfig table
    ---@param stageConfig StageConfig
    ---@param detectionManager DetectionManager
    ---@param logLevel LogLevel
    ---@param spawnManager SpawnManager
    function GlobalCapManager.start(database, capConfig, detectionManager, stageConfig, logLevel, spawnManager)
        if initiated == true then return end

        local logger = Spearhead.LoggerTemplate.new("AirbaseManager", logLevel)
        local bombTrackLogger = Spearhead.LoggerTemplate.new("RunwayBombingTracker", logLevel)
        local runwayBombingTracker = Spearhead.classes.capClasses.runwayBombing.RunwayBombingTracker.new(bombTrackLogger)

        local zones = database:getStagezoneNames()
        if zones then
            for key, stageName in pairs(zones) do
                if airbasesPerStage[stageName] == nil then
                    airbasesPerStage[stageName] = {}
                end

                local airbaseNames = database:getAirbaseNamesInStage(stageName)
                if airbaseNames then
                    for _, airbaseName in pairs(airbaseNames) do
                        if airbaseName then
                            local airbaseSpecificLogger = Spearhead.LoggerTemplate.new("CAP_" .. airbaseName, logLevel)
                            
                            local airbase = Spearhead.classes.capClasses.CapAirbase.new(airbaseName, database, airbaseSpecificLogger, capConfig, stageConfig, runwayBombingTracker, detectionManager, spawnManager)
                            
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



if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
Spearhead.classes.capClasses.GlobalCapManager = GlobalCapManager
