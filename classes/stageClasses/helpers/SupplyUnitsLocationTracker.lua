---@class SupplyUnitsLocationTracker
---@field private _unitPositions table<string, Vec3>
local SupplyUnitsLocationTracker = {}

-- A single class tracking all units is more than enough.
local singleton = nil

function SupplyUnitsLocationTracker.new()

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

    self._unitPositions[unit:getName()] = unit:getPoint()
end

---@private
function SupplyUnitsLocationTracker:IsSupplyUnit(unit)
    if unit == nil then return false end

    if unit:hasAttribute("Transport helicopters") then
        return true
    end

    return false
end

function SupplyUnitsLocationTracker:StartTracking()
    
    local function trackUnits(selfA, time)
        selfA:UpdateUnits()
        return time + 5
    end

    timer.scheduleFunction(trackUnits, self, timer.getTime() + 5)
end

function SupplyUnitsLocationTracker:UpdateUnits()
    for unitName, _ in pairs(self._unitPositions) do
        local unit = Unit.getByName(unitName)
        if unit and unit:isExist() then
            self._unitPositions[unitName] = unit:getPoint()
        else
            self._unitPositions[unitName] = nil
        end
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyUnitsLocationTracker = SupplyUnitsLocationTracker