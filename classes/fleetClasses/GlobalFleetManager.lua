

local GlobalFleetManager = {}

local fleetGroups = {}

GlobalFleetManager.start = function(database)

    local logger = Spearhead.LoggerTemplate.new("CARRIERFLEET", "INFO")

    local all_groups = Spearhead.classes.helpers.MizGroupsManager.getAllGroupNames()
    for _, groupName in pairs(all_groups) do
        if Spearhead.Util.startswith(string.lower(groupName), "carriergroup" ) == true then
            logger:info("Registering " .. groupName .. " as a managed fleet")
            local carrierGroup = Spearhead.internal.FleetGroup:new(groupName, database, logger)
            table.insert(fleetGroups, carrierGroup)
        end
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalFleetManager = GlobalFleetManager