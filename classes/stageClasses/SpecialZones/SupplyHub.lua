---@class SupplyHub
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _supplyUnitsTracker SupplyUnitsTracker
---@field private _isCommmandAdded table<string, boolean>
---@field private _missionCommandsHelper MissionCommandsHelper
---@field private _inZone table<string, boolean>
---@field private _drawID number
---@field private _cargoInUnits table<table<string, number>>
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

    self._supplyUnitsTracker = Spearhead.classes.stageClasses.helpers.SupplyUnitsLocationTracker.getOrCreate()
    self._inZone = {}
    self._missionCommandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(logger.LogLevel)

    self._logger:debug("Creating Supply Hub zone: " .. self._zoneName)

    return self
end

function SupplyHub:Activate()
    self._logger:debug("Activating Supply Hub zone: " .. self._zoneName)

    local zone = Spearhead.DcsUtil.getZoneByName(self._zoneName)

    if zone and self._drawID == nil then
        local fillColor = {0, 1, 0, 0.5}
        local lineColor = {0, 1, 0, 1}
        local lineStyle = 1
        self._drawID = Spearhead.DcsUtil.DrawZone(zone, fillColor, lineColor, lineStyle)
    end

    self:StartMonitoringUnitsForCommands()
end

---Loads a crate directly into the unit
---@param groupID number
---@param crateType SupplyType  
function SupplyHub:UnitRequestCrateLoading(groupID, crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group ~= nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[crateType]
        if crateConfig == nil then
            self._logger:error("Invalid crate type: " .. crateType)
            return
        end

        local unit = group:getUnit(1)
        if unit == nil then return end
        if unit:isExist() == false then return end

        trigger.action.setUnitInternalCargo(unit:getName(), crateConfig.weight)
        self._supplyUnitsTracker:AddCargoToUnit(unit:getID(), crateType)
        trigger.action.outTextForUnit(unit:getID(), "Loaded crate of type " .. crateType, 10)

    end
end


---Spawns a crate for sling loading
---@param groupID number
---@param crateType SupplyType
function SupplyHub:UnitRequestCrateSpawn(groupID, crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[crateType]
        if crateConfig == nil then
            self._logger:error("Invalid crate type: " .. crateType)
            return
        end

        

    end
end

function SupplyHub.UnloadRequested(groupID, crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then
        return
    end

    local unit = group:getUnit(1)
    if not unit or unit:isExist() ~= true then return end

    

end

function SupplyHub:StartMonitoringUnitsForCommands()
    self._logger:debug("Starting to monitor units for commands in Supply Hub zone: " .. self._zoneName)

    ---@param selfA SupplyHub
    ---@param time number
    local monitorTask = function(selfA, time)
        selfA:CheckUnitsInZone()
        return time + 5
    end

    timer.scheduleFunction(monitorTask, self, timer.getTime() + 10)
end

function SupplyHub:CheckUnitsInZone()
    local units = self._supplyUnitsTracker:GetUnits()
    for _, unit in ipairs(units) do
        if unit and unit:isExist() then
           local pos = unit:getPoint()
           if Spearhead.DcsUtil.isPositionInZone(pos.x, pos.z, self._zoneName) then
                local group = unit:getGroup()
                if group then
                    self._missionCommandsHelper:AddSupplyHubCommandsForGroup(group:getID(), self)
                end
            else
                if self._inZone[unit:getName()] == true then
                    self._inZone[unit:getName()] = false
                    self._logger:debug("Unit " .. unit:getName() .. " left the zone " .. self._zoneName)
                end
            end
        end
    end
end


if not Spearhead then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.SupplyHub = SupplyHub