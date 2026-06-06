local Logger = require("classes.util.Logger")
local Util = require("classes.util.Util")
local RunwayBombingTracker = require("classes.capClasses.runwayBombing.RunwayBombingTracker")
local CapAirbase = require("classes.capClasses.CapAirbase")

---@class GlobalCapManager
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

        local logger = Logger.new("AirbaseManager", logLevel)
        local bombTrackLogger = Logger.new("RunwayBombingTracker", logLevel)
        local runwayBombingTracker = RunwayBombingTracker.new(bombTrackLogger)

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
                            local airbaseSpecificLogger = Logger.new("CAP_" .. airbaseName, logLevel)
                            
                            local airbase = CapAirbase.new(airbaseName, database, airbaseSpecificLogger, capConfig, stageConfig, runwayBombingTracker, detectionManager, spawnManager)
                            
                            if airbase then
                                table.insert(airbasesPerStage[stageName], airbase)
                                allAirbasesByName[airbaseName] = airbase
                            end
                        end
                    end
                end
            end
        end

        logger:info("Initiated " .. Util.tableLength(allAirbasesByName) .. " airbases for cap")
        initiated = true

        ---returns if there is CAP active 
        ---@param zoneName any
        ---@param activeZoneNumber number
        ---@return boolean
        GlobalCapManager.IsCapActiveWhenZoneIsActive = function(zoneName, activeZoneNumber)
            for _, airbase in pairs(airbasesPerStage[zoneName]) do
                if airbase:IsBaseActiveWhenStageIsActive(activeZoneNumber) == true then
                    return true
                end
            end
            return false
        end
    end
end

return GlobalCapManager
