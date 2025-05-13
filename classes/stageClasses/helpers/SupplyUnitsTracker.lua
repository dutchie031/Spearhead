---@class SupplyUnitsTracker
---@field private _supplyUnits Array<Unit>
local SupplyUnitsLocationTracker = {}

-- A single class tracking all units is more than enough.
local singleton = nil

function SupplyUnitsLocationTracker.getOrCreate()

    if singleton == nil then
        singleton = setmetatable({}, SupplyUnitsLocationTracker)
        singleton._logger = Spearhead.LoggerTemplate.new("SupplyUnitsLocationTracker", "INFO")
        singleton._unitPositions = {}

        Spearhead.Events.AddOnPlayerEnterUnitListener(singleton)
    end

    return singleton

end

---@param unit Unit
function SupplyUnitsLocationTracker:OnPlayerEntersUnit(unit)
    if unit == nil then return end

    if self:IsSupplyUnit(unit) == false then return end
    table.insert(self._supplyUnits, unit)
end

---@private
function SupplyUnitsLocationTracker:IsSupplyUnit(unit)
    if unit == nil then return false end

    if unit:hasAttribute("Transport helicopters") then
        return true
    end

    return false
end

---@return Array<Unit>
function SupplyUnitsLocationTracker:GetUnits()
    return self._supplyUnits
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyUnitsLocationTracker = SupplyUnitsLocationTracker