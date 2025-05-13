---@class SupplyUnitsTracker
---@field private _supplyUnits Array<Unit>
---@field private _cargoInUnits table<string, table<SupplyType, number>>
local SupplyUnitsTracker = {}

-- A single class tracking all units is more than enough.
local singleton = nil

---comment
---@return SupplyUnitsTracker
function SupplyUnitsTracker.getOrCreate()

    if singleton == nil then
        singleton = setmetatable({}, SupplyUnitsTracker)
        singleton._logger = Spearhead.LoggerTemplate.new("SupplyUnitsLocationTracker", "INFO")
        singleton._unitPositions = {}

        Spearhead.Events.AddOnPlayerEnterUnitListener(singleton)
    end

    return singleton

end

---@param unit Unit
function SupplyUnitsTracker:OnPlayerEntersUnit(unit)
    if unit == nil then return end

    if self:IsSupplyUnit(unit) == false then return end
    table.insert(self._supplyUnits, unit)
end

---@private
function SupplyUnitsTracker:IsSupplyUnit(unit)
    if unit == nil then return false end

    if unit:hasAttribute("Transport helicopters") then
        return true
    end

    return false
end

---comment
---@param unitID number
---@param crateType SupplyType
function SupplyUnitsTracker:AddCargoToUnit(unitID, crateType)

    if unitID == nil or crateType == nil then return end

    local unit = Spearhead.DcsUtil.GetUnitByID(unitID)
    if unit == nil then return end

    if self._cargoInUnits[unitID] == nil then
        self._cargoInUnits[unitID] = {}
    end

    if self._cargoInUnits[unitID][crateType] == nil then
        self._cargoInUnits[unitID][crateType] = 0
    end

    self._cargoInUnits[unitID][crateType] = self._cargoInUnits[unitID][crateType] + 1

end

---@param unitID number
---@param crateType SupplyType
function SupplyUnitsTracker:RemoveCargoFromUnit(unitID, crateType)

    if unitID == nil or crateType == nil then return end

    local unitIDStr = tostring(unitID)
    if self._cargoInUnits[unitIDStr] == nil then return end

    if self._cargoInUnits[unitIDStr][crateType] == nil then return end

    self._cargoInUnits[unitIDStr][crateType] = self._cargoInUnits[unitIDStr][crateType] - 1

    local hasCargo = false
    for type, count in pairs(self._cargoInUnits[unitIDStr]) do
        if count > 0 then
            hasCargo = true
            break
        end
    end
    if hasCargo == false then
        self._cargoInUnits[unitIDStr] = nil
    end

end

---@param unitID number
---@return table<SupplyType, number>?
function SupplyUnitsTracker:GetCargoInUnit(unitID)
    if unitID == nil then return end

    local unitIDStr = tostring(unitID)
    if self._cargoInUnits[unitIDStr] == nil then return end

    return self._cargoInUnits[unitIDStr]
end

---@return Array<Unit>
function SupplyUnitsTracker:GetUnits()
    return self._supplyUnits
end



if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker = SupplyUnitsTracker