---@class InterceptGroup : AirGroup
---@field private _targetNames Array<string>
---@field private _targetZoneName string
---@field private _detectionManager DetectionManager
---@field private _coalitionSide CoalitionSide
---@field private _lastKnownTargetAt number
---@field private _targetZoneIdPerStage table<string, string>
---@field private _config CapConfig
---@field private _airbase Airbase
---@field private _updateTaskID number|nil
local InterceptGroup = {}
InterceptGroup.__index = InterceptGroup


---@param groupName string
---@param config CapConfig
---@param logger Logger
---@param detectionManager DetectionManager
---@return InterceptGroup?
function InterceptGroup.New(groupName, config, logger, detectionManager)

    setmetatable(InterceptGroup, Spearhead.classes.capClasses.airGroups.AirGroup)
    local self = setmetatable({}, InterceptGroup)
    Spearhead.classes.capClasses.airGroups.AirGroup.New(self, groupName, "INTERCEPT", config, logger)

    local group = Group.getByName(groupName)
    if not group then
        logger:error("InterceptGroup: Group " .. groupName .. " does not exist")
        return nil
    end
    self._coalitionSide = group:getCoalition()
    self._detectionManager = detectionManager
    self._config = config
    self._targetNames = {}
    self._targetZoneIdPerStage = {}

    return self
end

---comment
---@param units Array<string>
---@param homeAirbase Airbase
function InterceptGroup:SendToInterceptUnits(units, zoneName,  homeAirbase)

    self._airbase = homeAirbase
    self._targetZoneName = zoneName
    self:SetTargetUnits(units)
end

---@return string?
function InterceptGroup:GetZoneIDWhenStageID(stageID)
    return self._targetZoneIdPerStage[stageID]
end

---@return string? 
function InterceptGroup:GetCurrentTargetZone()
    return self._targetZoneName
end

---comment
---@param unitNames Array<string>
function InterceptGroup:SetTargetUnits(unitNames)

    self._targetNames = unitNames
    self:UpdateTask()

    if self._updateTaskID then
        timer.removeFunction(self._updateTaskID)
    end

    local updateContinous = function(selfA, time)
        local next = selfA:UpdateTask()
        if next then
            return time + next
        else
            return nil
        end
    end
    self._updateTaskID = timer.scheduleFunction(updateContinous, self, timer.getTime() + 30)
end

function InterceptGroup:RemoveTargetUnit(unit)

    if not unit then return end

    local name = unit:getName()
    for key, value in pairs(self._targetNames) do
        if value == "name" then
            table.remove(self._targetNames, key)
            self._logger:debug("InterceptGroup: Removed target unit " .. name .. " from group " .. self._groupName)
            break
        end
    end
end

---@return number? @interval or null if no retry required
function InterceptGroup:UpdateTask()
    local group = Group.getByName(self._groupName)
    if not group then return end

    local selfDetected = false
    for _, unit in pairs(group:getUnits()) do
        if unit and unit:isExist() then
            local controller = unit:getController()
            if controller then
                for _, detected in pairs(controller:getDetectedTargets()) do
                    if detected and detected.object then
                        for _, targetName in pairs(self._targetNames) do
                            if detected.object:getName() == targetName then
                                selfDetected = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    if Spearhead.DcsUtil.IsBingoFuel(self._groupName) then
        self._logger:debug("InterceptGroup: " .. self._groupName .. " is at bingo fuel, returning to base")
        self:SendRTB(self._airbase)
        return nil -- Return to base if bingo fuel
    end

    if selfDetected then
        --JUDY JUDY, no adjustments to be made
        return 30 -- Just continue attacking the detected target
    end

    local groupPoint = nil
    for _, unit in pairs(group:getUnits()) do
        if unit and unit:isExist() then
            groupPoint = unit:getPoint()
            break
        end
    end

    if groupPoint == nil then return end

    local closestUnit = nil
    local closestDistance = math.huge

    -- if not self detected then check if the target it detected by the detection manager
    for _, targetName in pairs(self._targetNames) do
        if self._detectionManager:IsUnitDetectedBy(targetName, self._coalitionSide) then
            local targetUnit = Unit.getByName(targetName)
            if targetUnit and targetUnit:isExist() then
                local pos = targetUnit:getPoint()
                local distance = Spearhead.Util.VectorDistance3d(groupPoint, pos)
                if distance < closestDistance then
                    closestDistance = distance
                    closestUnit = targetUnit
                end
            end
        end
    end

    if closestUnit == nil then return 30 end

    local speed = self._config:getMaxSpeed()
    local interceptPoint = self:GetInterceptPoint(groupPoint, speed, closestUnit)

    if interceptPoint == nil then
        return 30 -- Return to base if no intercept point could be calculated
    end

    local isInAir = false
    for _, unit in pairs(group:getUnits()) do
        if unit and unit:isExist() and unit:inAir() then
            isInAir = true
            break
        end
    end

    local mission = nil
    if isInAir == true then
        -- If the group is in the air, create an intercept mission
        mission = Spearhead.classes.capClasses.taskings.INTERCEPT.getMissionFromInAir(
            self._groupName,
            { x = groupPoint.x, y = groupPoint.z },
            interceptPoint,
            self._airbase,
            self._config
        )
    else
        mission = Spearhead.classes.capClasses.taskings.INTERCEPT.getMissionFromAirbase(
            self._groupName,
            interceptPoint,
            self._airbase,
            self._config
        )
    end

    if mission then
        self:SetMission(mission)
    else
        self._logger:warn("InterceptGroup: Could not create mission for group " .. self._groupName)
        return 30 -- Return to base if mission could not be created
    end

    return 30
end


---@param originatingUnit Vec3
---@param speed number 
---@param targetUnit Unit
---@return Vec2? @Returns the intercept point as a Vec2 or nil if no intercept point could be calculated
function InterceptGroup:GetInterceptPoint(originatingUnit, speed, targetUnit)

    -- Calculate intercept point for a moving target
    -- originatingUnit: Vec3 (our position)
    -- speed: our speed (scalar, m/s)
    -- targetUnit: Unit (target)

    if not targetUnit or not targetUnit:isExist() then return nil end

    local targetPos = targetUnit:getPoint()
    local targetVel = targetUnit:getVelocity() -- Vec3
    local relPos = {
        x = targetPos.x - originatingUnit.x,
        y = targetPos.y - originatingUnit.y,
        z = targetPos.z - originatingUnit.z
    }
    local relVel = {
        x = targetVel.x,
        y = targetVel.y,
        z = targetVel.z
    }
    local relPos2 = relPos.x^2 + relPos.y^2 + relPos.z^2
    local relVel2 = relVel.x^2 + relVel.y^2 + relVel.z^2
    local speed2 = speed^2
    local dot = relPos.x * relVel.x + relPos.y * relVel.y + relPos.z * relVel.z

    -- Quadratic formula: a*t^2 + b*t + c = 0
    local a = relVel2 - speed2
    local b = 2 * dot
    local c = relPos2
    local discriminant = b^2 - 4*a*c
    if discriminant < 0 or a == 0 then
        -- No solution, just head to current position
        return { x = targetPos.x, y = targetPos.z }
    end
    local sqrtDisc = math.sqrt(discriminant)
    local t1 = (-b + sqrtDisc) / (2*a)
    local t2 = (-b - sqrtDisc) / (2*a)
    local t = math.min(t1, t2)
    if t < 0 then t = math.max(t1, t2) end
    if t < 0 then
        -- No valid intercept time, just head to current position
        return { x = targetPos.x, y = targetPos.z }
    end
    -- Intercept point
    local intercept = {
        x = targetPos.x + targetVel.x * t,
        y = targetPos.z + targetVel.z * t
    }
    return intercept
end



---@private
function InterceptGroup:InitWithName(groupName)
    local split_string = Spearhead.Util.split_string(groupName, "_")
    local partCount = Spearhead.Util.tableLength(split_string)
    if partCount >= 3 then
        local configPart = split_string[2]
        configPart = string.sub(configPart, 2, #configPart)
        local subsplit = Spearhead.Util.split_string(configPart, "|")
        if subsplit then
            for key, value in pairs(subsplit) do
                local keySplit = Spearhead.Util.split_string(value, "]")
                local targetZone = keySplit[2]
                local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                for _, value in pairs(commaSeperated) do
                    local dashSeperated = Spearhead.Util.split_string(value, "-")
                    if Spearhead.Util.tableLength(dashSeperated) > 1 then
                        local from = tonumber(dashSeperated[1])
                        local till = tonumber(dashSeperated[2])

                        for i = from, till do
                            if Spearhead.Util.strContains(targetZone, "A") == true then
                                self._targetZoneIdPerStage[tostring(i)] = string.gsub(targetZone, "A", tostring(i))
                            else
                                self._targetZoneIdPerStage[tostring(i)] = targetZone
                            end
                        end
                    else
                        if Spearhead.Util.strContains(targetZone, "A") == true then
                            self._targetZoneIdPerStage[tostring(dashSeperated[1])] = string.gsub(targetZone, "A", tostring(dashSeperated[1]))
                        else
                            self._targetZoneIdPerStage[tostring(dashSeperated[1])] = targetZone
                        end
                    end
                end
            end
        end

        env.info("Capgroup parsed with table: " .. Spearhead.Util.toString(self._targetZoneIdPerStage))

    else
        Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
    end
end


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.airGroups then Spearhead.classes.capClasses.airGroups = {} end
Spearhead.classes.capClasses.airGroups.InterceptGroup = InterceptGroup