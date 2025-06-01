---@class AirGroup : OnUnitLostListener
---@field protected _logger Logger
---@field protected _groupName string
---@field protected _groupType AirGroupType
---@field protected _state AirGroupState
---@field protected _isSpawned boolean
---@field protected _config CapConfig
---@field protected _checkLivenessNumber number
local AirGroup = {}
AirGroup.__index = AirGroup

---@param logger Logger
---@param groupName string
---@param groupType AirGroupType
---@param config CapConfig
function AirGroup:New(groupName, groupType, config, logger)
    self._groupName = groupName
    self._groupType = groupType
    self._isSpawned = false
    self._state = "UnSpawned" -- Default state
    self._config = config
    self._logger = logger

    local group = Group.getByName(self._groupName)
    if group then
        Spearhead.Events.addOnGroupRTBListener(self._groupName, self)
        Spearhead.Events.addOnGroupRTBInTenListener(self._groupName, self)
        Spearhead.Events.addOnGroupOnStationListener(self._groupName, self)

        for _, unit in pairs(group:getUnits()) do
            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
            Spearhead.Events.addOnUnitLandEventListener(unit:getName(), self)
        end
        Spearhead.DcsUtil.DestroyGroup(self._groupName)
    end
end

function AirGroup:GetState()
    return self._state
end

function AirGroup:GetName()
    return self._groupName
end

function AirGroup:MarkRearmComplete()
    self:Respawn(false)
    if self._state == "Rearming" then
        self:SetState("ReadyOnTheRamp")
    end
end

---@protected
function AirGroup:SetMission(mission)
    self:SetState("InTransit")

    local group = Group.getByName(self._groupName)
    if group then
        local controller = group:getController()
        if controller then
            controller:setCommand({
                id = 'Start',
                params = {}
            })
        end
    end

    local setMissionDelayed = function(data, time)
        data.self:SetMissionPrivate(data.mission)
    end

    local data = {
        self = self,
        mission = mission
    }

    timer.scheduleFunction(setMissionDelayed, data, timer.getTime() + 5)
end

function AirGroup:SetMissionPrivate(mission)
    self:SetState("InTransit")
    local group = Group.getByName(self._groupName)
    if group and mission then
        group:getController():setTask(mission)
        self._logger:debug("mission - Task set for group: " .. self._groupName)
    end
end

---@param airbase Airbase
function AirGroup:SendRTB(airbase)
    self._logger:debug("AirGroup:SendRTB called for group: " .. self._groupName)
    self:SetState("Rtb")
    local group = Group.getByName(self._groupName)
    if group then
        ---@type Vec3
        local location = nil
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() == true and unit:inAir() == true then
                location = unit:getPoint()
                break
            end
        end
        if location then
            local mission = Spearhead.classes.capClasses.taskings.RTB.getAsMission(airbase, { x= location.x, y= location.z }, self._config)
            group:getController():setTask(mission)
            self._logger:debug("AirGroup:SendRTB - Task set for group: " .. self._groupName)
        end
    end
end

function AirGroup:Spawn()
    if self._isSpawned then return end
    self:SpawnInternal(false)
end

---@param force boolean
---@param withoutLoadout boolean?
---@protected
function AirGroup:SpawnInternal(force, withoutLoadout)

    if withoutLoadout == nil then withoutLoadout = false end

    if self._isSpawned and force ~= true then return end

    local group, isStatic = Spearhead.DcsUtil.SpawnGroupTemplate(self._groupName, nil, nil, true, nil, withoutLoadout)
    if isStatic == true then
        --- If For Some reaons someone tries to schedule static units as CAP classes
        self._state = "UnSpawned"
        return
    end

    if group then
        self._group = group
        self._isSpawned = true
        self._initialSize = #group:getUnits()
        self._liveState = {}
    else
        self._logger:error("Failed to spawn group: " .. self._groupName)
    end

    if self._state == "UnSpawned" then
        self:SetState("ReadyOnTheRamp")
    end

    ---@param selfA AirGroup
    local function CheckLivenessTask(selfA, time)
        local interval = selfA:CheckLiveness()
        if not interval then return end
        return time + interval
    end

    if self._checkLivenessNumber then
        timer.removeFunction(self._checkLivenessNumber)
    end

    self._checkLivenessNumber = timer.scheduleFunction(CheckLivenessTask, self, timer.getTime() + 5)
end


---@param withoutLoadout boolean?
function AirGroup:Respawn(withoutLoadout)
    self:SpawnInternal(true, withoutLoadout)
end

---@protected
---@param state AirGroupState
function AirGroup:SetState(state)
    if self._state == state then return end
    self._state = state
    self._logger:debug("AirGroup:State changed for group: " .. self._groupName .. " to state: " .. state)
end

---@return number? timeInterval
function AirGroup:CheckLiveness()
    local isAlive = false
    local group = Group.getByName(self._groupName)

    if group and group:isExist() == true then
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() == true and unit:getLife() > (unit:getLife0() * 0.3) then
                isAlive = true
            end
        end
    end

    if isAlive == false then
        self:SetState("Dead")
        self:CheckStateAndStartRepairRearm()
        return nil
    end

    return 10
end

---@protected
function AirGroup:OnLastUnitLanded()
    --- Once landed monitor the units until it's at it's designated location (or died)

    -- Units

    ---@class CheckGroupForRestartData
    ---@field self AirGroup
    ---@field lastLocations table<string,Vec3>
    ---@field lastChangeTime number

    ---@param data CheckGroupForRestartData
    ---@param time number
    local checkGroupForRestart = function(data, time)
        local group = Group.getByName(data.self:GetName())
        if not group then
            self:CheckStateAndStartRepairRearm()
            return
        end

        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() then
                local pos = unit:getPoint()


                if data.lastLocations[unit:getName()] == nil then
                    data.lastLocations[unit:getName()] = pos
                    return time + 5
                end

                if pos and Spearhead.Util.VectorDistance3d(pos, data.lastLocations[unit:getName()]) > 10 then
                    data.lastChangeTime = time
                end
                data.lastLocations[unit:getName()] = pos
            end
        end

        if data.lastChangeTime + 30 < time then
            -- If no change in 30 seconds, assume all units are parked
            local withoutLoadout = true
            data.self:Respawn(withoutLoadout)
            data.self:CheckStateAndStartRepairRearm()
            return
        end

        return time + 5
    end

    ---@type CheckGroupForRestartData
    local data = {
        self = self,
        lastLocations = {},
        lastChangeTime = timer.getTime()
    }

    local group = Group.getByName(self._groupName)
    if group then
        for _, unit in pairs(group:getUnits()) do
            data.lastLocations[unit:getName()] = unit:getPoint()
        end
    end
    timer.scheduleFunction(checkGroupForRestart, data, timer.getTime() + 5)
    self._logger:debug("AirGroup:OnLastUnitLanded - Monitoring group: " .. self._groupName)
end

function AirGroup:CheckStateAndStartRepairRearm()
    self._logger:debug("AirGroup:CheckStateAndStartRepairRearm called for group: " .. self._groupName)
    local group = Group.getByName(self._groupName)
    local anyAlive = false
    local allAlive = true

    if group then
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() == true and unit:getLife() > (unit:getLife0() * 0.3) then
                anyAlive = true
            else
                allAlive = false
            end
        end
    end

    if anyAlive == false then
        -- Schedule Spawn + Repair + Rearm
        self:StartRespawn()
        return
    end

    if allAlive == false then
        --- Schedule Spawn + Repair + Rearm
        self:StartRepair()
        return
    end

    --- Reschedule  Spawn + Rearm
    self:StartRearm()
end

do --- RESPAWN FUNCTIONS
    --[[
        TODO: Checks to be added to the functions in case a group is destroyed while waiting for repair/rearm.
    ]]

    function AirGroup:StartRespawn()
        self:SetState("Dead")

        local respawnTask = function(selfA, time)
            selfA:RepairDelayed()
        end

        local delay = self._config:getDeathDelay()
        if delay < 2 then
            delay = 2
        end
        return timer.scheduleFunction(respawnTask, self, timer.getTime() + delay)
    end

    function AirGroup:StartRepair()
        self:SetState("Repairing")

        if self._isSpawned == false then
            self:Spawn()
        end

        local rearmTask = function(selfA, time)
            self:StartRearm()
        end

        local delay = self._config:getRepairDelay()
        if delay < 2 then
            delay = 2
        end

        return timer.scheduleFunction(rearmTask, self, timer.getTime() + delay)
    end

    function AirGroup:StartRearm()
        self:SetState("Rearming")

        if self._isSpawned == false then
            self:Spawn()
        end

        local rearmDelay = self._config:getRearmDelay()
        if rearmDelay < 2 then
            rearmDelay = 2
        end

        ---@param selfA AirGroup
        local rearmTask = function(selfA, time)
            selfA:MarkRearmComplete()
        end

        -- Schedule Rearm Complete
        return timer.scheduleFunction(rearmTask, self, timer.getTime() + rearmDelay)
    end
end


do --EVENT LISTENERS
    ---@param unit Unit
    function AirGroup:OnUnitLost(unit)
        self:CheckLiveness()
    end

    ---@param groupName string
    function AirGroup:OnGroupRTBInTen(groupName)
        if self._groupName == groupName then
            self._logger:debug("AirGroup:OnGroupRTBInTen called for group: " .. self._groupName)
            self:SetState("RtbInTen")
        end
    end

    ---@param groupName string
    function AirGroup:OnGroupRTB(groupName)
        if self._groupName == groupName then
            self._logger:debug("AirGroup:OnGroupRTB called for group: " .. self._groupName)
            self:SetState("Rtb")
        end
    end

    function AirGroup:OnUnitLanded(unit, airbase)
        local anyInAir = false
        local group = Group.getByName(self._groupName)
        if group then
            for _, u in pairs(group:getUnits()) do
                if u and u:isExist() == true and u:inAir() == true then
                    anyInAir = true
                    break
                end
            end
        end

        if not anyInAir then
            self:OnLastUnitLanded()
        end
    end

    function AirGroup:OnGroupOnStation(groupName)
        if self._groupName == groupName then
            self:SetState("OnStation")
        end
    end
end

function AirGroup:Destroy()
    Spearhead.DcsUtil.DestroyGroup(self._groupName)
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.airGroups then Spearhead.classes.capClasses.airGroups = {} end
Spearhead.classes.capClasses.airGroups.AirGroup = AirGroup

---@alias AirGroupState
---| "UnSpawned"
---| "ReadyOnTheRamp
---| "InTransit"
---| "OnStation"
---| "RtbInTen"
---| "Rtb"
---| "Dead"
---| "Repairing"
---| "Rearming"


---@alias AirGroupType
---| "CAP"

---| "CAS"
---| "SEAD"
---| "INTERCEPT"
---| ""
