---@class SupplyHub
---@field _database Database
---@field _logger Logger
---@field _zoneName string
local SupplyHub = {}

---@param database Database
---@param logger Logger
---@param zoneName string
---@return SupplyHub?
function SupplyHub.new(database, logger, zoneName)

    SupplyHub.__index = SupplyHub
    local self = setmetatable({}, SupplyHub)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    

    return self

end

function SupplyHub:Activate()
    self._logger:debug("Activating Supply Hub zone: " .. self._zoneName)
end

function SupplyHub:StartMonitoringUnitsForCommands()
    self._logger:debug("Starting to monitor units for commands in Supply Hub zone: " .. self._zoneName)

    ---@param selfA SupplyHub
    ---@param time number
    local monitorTask = function(selfA, time)

        

        return time + 10
    end

    timer.scheduleFunction(monitorTask, self, timer.getTime() + 10)
end

function SupplyHub:AddCommandsToGroup(group)
    if group == nil then return end

    
end

---@param supplyType SupplyType
function SupplyHub:SpawnSupplyCrate(supplyType)

    

end


---@alias SupplyType
---| "BLUE_SAM"


if not Spearhead then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.SupplyHub = SupplyHub