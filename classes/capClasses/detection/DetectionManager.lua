
---@class DetectionManager
---@field private _logger Logger
---@field private _detectedUnits table<string, table<string, number>>
---@field private _detectingUnits table<string, table<string, Unit>>
local DetectionManager = {}
DetectionManager.__index = DetectionManager


---@param logger Logger
function DetectionManager.New(logger)
    local self = setmetatable({}, DetectionManager)

    self._logger = logger
    self._detectedUnits = {
        [tostring(coalition.side.RED)] = {},
        [tostring(coalition.side.BLUE)] = {}
    }

    self._detectingUnits = {
        [tostring(coalition.side.RED)] = {},
        [tostring(coalition.side.BLUE)] = {}
    }

    ---@param selfA DetectionManager
    ---@param time number
    local updateDetectingUnitsTask = function(selfA, time)
        selfA:UpdateDetectingUnits()
        return time + 120
    end
    timer.scheduleFunction(updateDetectingUnitsTask, self, timer.getTime() + 120)

    ---@param selfA DetectionManager
    ---@param time number
    local updateDetected = function(selfA, time)
        selfA:UpdateDetectedUnits()
        return time + 10
    end
    timer.scheduleFunction(updateDetected, self, timer.getTime() + 130)
    

    return self
end

---@param unitName string
---@param coalitionSide CoalitionSide
function DetectionManager:IsUnitDetectedBy(unitName, coalitionSide)
    local coalitionString = tostring(coalitionSide)
    if not self._detectedUnits[coalitionString] then
        return false
    end

    if not self._detectedUnits[coalitionString][unitName] then
        return false
    end

    return timer.getTime() - self._detectedUnits[coalitionString][unitName] < 20
end

---@return Array<string>
function DetectionManager:GetDetectedUnitsBy(coalitionSide)
    local coalitionString = tostring(coalitionSide)
    if not self._detectedUnits[coalitionString] then
        return {}
    end

    local detectedUnits = {}
    for unitName, _ in pairs(self._detectedUnits[coalitionString]) do
        if self:IsUnitDetectedBy(unitName, coalitionSide) then
            table.insert(detectedUnits, unitName)
        end
    end

    return detectedUnits
end

function DetectionManager:UpdateDetectingUnits()
    self:UpdateDetectingInCoalition(coalition.side.RED)
    self:UpdateDetectingInCoalition(coalition.side.BLUE)
    self._logger:debug("Updated detecting units")
end

function DetectionManager:UpdateDetectedUnits()
    self:UpdateDetectedUnitsByCoalition(coalition.side.RED)
    self:UpdateDetectedUnitsByCoalition(coalition.side.BLUE)
    self._logger:debug("Updated detected units")
end

---@private
---@param unit Unit
---@return boolean
function DetectionManager:IsDetectingType(unit)
    return unit:hasAttribute("EWR") or unit:hasAttribute("AWACS") or unit:hasAttribute("SAM SR")
end

---@private
---@param coalitionSide CoalitionSide
function DetectionManager:UpdateDetectingInCoalition(coalitionSide)

    local coalitionString = tostring(coalitionSide)

    local airGroups = coalition.getGroups(coalitionSide, Group.Category.AIRPLANE)
    for _, group in ipairs(airGroups) do
        if group and group:isExist() then
            for _, unit in ipairs(group:getUnits()) do
                if unit and self:IsDetectingType(unit) == true then
                    self._detectingUnits[coalitionString][unit:getName()] = unit
                end
            end
        end
    end

    local groundGroups = coalition.getGroups(coalitionSide, Group.Category.GROUND)
    for _, group in ipairs(groundGroups) do
        if group and group:isExist() then
            for _, unit in ipairs(group:getUnits()) do
                if unit and self:IsDetectingType(unit) == true then
                    self._detectingUnits[coalitionString][unit:getName()] = unit
                end
            end
        end
    end

    local ships = coalition.getGroups(coalitionSide, Group.Category.SHIP)
    for _, group in ipairs(ships) do
        if group and group:isExist() then
            for _, unit in ipairs(group:getUnits()) do
                if unit and self:IsDetectingType(unit) == true then
                    self._detectingUnits[coalitionString][unit:getName()] = unit
                end
            end
        end
    end

end

---@private
---@param coalitionSide CoalitionSide
function DetectionManager:UpdateDetectedUnitsByCoalition(coalitionSide)

    local coalitionString = tostring(coalitionSide)
    if not self._detectingUnits[coalitionString] then return end
    if not self._detectedUnits[coalitionString] then
        self._detectedUnits[coalitionString] = {}
    end

    for _, detectingUnit in pairs(self._detectingUnits[coalitionString]) do
        if detectingUnit and detectingUnit:isExist() then
            local controller = detectingUnit:getController()
            if controller then
                local targets = controller:getDetectedTargets(Controller.Detection.RADAR)
                for _, target in pairs(targets) do
                    if target and target.object ~= nil and target.distance == true then
                        local targetUnit = target.object
                        local name = targetUnit:getName()
                        self._detectedUnits[coalitionString][name] = timer.getTime()
                    end
                end
            end
        end
    end
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.detection then Spearhead.classes.capClasses.detection = {} end
Spearhead.classes.capClasses.detection.DetectionManager = DetectionManager
