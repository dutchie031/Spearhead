local Logger = require("classes.util.Logger")
local Util = require("classes.util.Util")
local FleetGroup = require("classes.fleetClasses.FleetGroup")
local MizGroupsManager = require("classes.helpers.MizGroupsManager")


---@class GlobalFleetManager
local GlobalFleetManager = {}

local fleetGroups = {}

GlobalFleetManager.start = function(database)

    local logger = Logger.new("CARRIERFLEET", "INFO")

    local all_groups = MizGroupsManager.getAllGroupNames()
    for _, groupName in pairs(all_groups) do
        if Util.startswith(string.lower(groupName), "carriergroup" ) == true then
            logger:info("Registering " .. groupName .. " as a managed fleet")
            local carrierGroup = FleetGroup:new(groupName, database, logger)
            table.insert(fleetGroups, carrierGroup)
        end
    end
end

return GlobalFleetManager