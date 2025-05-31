

---@class AirGroup : OnUnitLostListener
---@field private _groupName string
---@field private _groupType AirGroupType
---@field private _state GroupState
---@field private _isSpawned boolean
---@field private _config CapConfig
---@field private _checkLivenessNumber number
---@field private _onStateChangedListeners Array<OnAirGroupStateChangedListener>
local AirGroup = {}
AirGroup.__index = AirGroup

---@param groupName string
---@param groupType AirGroupType
---@param config CapConfig
function AirGroup:New(groupName, groupType, config)

    setmetatable(self, AirGroup)

    self._groupName = groupName
    self._groupType = groupType
    self._isSpawned = false
    self._state = "UnSpawned" -- Default state
    self._config = config
    self._onStateChangedListeners = {}

    local group = Group.getByName(self._groupName)
    if group then 
        for _, unit in pairs(group:getUnits()) do
            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
            Spearhead.Events.addOnGroupRTBInTenListener(self._groupName, self)
            Spearhead.Events.addOnGroupRTBListener(self._groupName, self)
        end

    end
end

function AirGroup:GetName()
    return self._groupName
end

function AirGroup:MarkRearmComplete()
    if self._state == "Rearming" then
        self:SetState("ReadOnTheRamp")
    end
end

function AirGroup:Spawn()
    if self._isSpawned then return end

    local group, isStatic = Spearhead.DcsUtil.SpawnGroupTemplate(self._groupName, nil, nil, true)
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
        Spearhead.DcsUtil.LogError("Failed to spawn group: " .. self._groupName)
    end

    if self._state == "UnSpawned" then
        self:SetState("ReadOnTheRamp")
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

---@class OnAirGroupStateChangedListener
---@field OnStateChanged fun(self:OnAirGroupStateChangedListener, groupName:string, state:GroupState)

function AirGroup:AddOnStateChangedListener(listener)
    if type(listener) == "table" and listener.OnStateChanged then
        table.insert(self._onStateChangedListeners, listener)
    else
        Spearhead.DcsUtil.LogError("Invalid listener for AirGroup state change: " .. tostring(listener))
    end
end


---@protected
---@param state GroupState
function AirGroup:SetState(state)

    if self._state == state then return end
    self._state = state

    -- TODO: Notify State Change listeners
    for _, listener in pairs(self._onStateChangedListeners) do
        pcall(function()
            listener:OnStateChanged(self._groupName, self._state)
        end)
    end

end


---@return number? timeInterval
function AirGroup:CheckLiveness()

    local isAlive = false
    local group = Group.getByName(self._groupName)

    if group and group:isExist() == true  then
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
    

end

function AirGroup:OnLastUnitParked()

end

function AirGroup:CheckStateAndStartRepairRearm()

    local group = Group.getByName(self._groupName)
    local anyAlive = false
    local allAlive = true

    if group then
        for _, unit in pairs(group) do
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

        local rearmDelay = self._config:getRearmDelay()
        if rearmDelay < 2 then
            rearmDelay = 2
        end

        local rearmTask = function(selfA, time)
            self:MarkRearmComplete()
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
        self:SetState("RtbInTen")
    end

    ---@param groupName string
    function AirGroup:OnGroupRTB(groupName)
        self:SetState("Rtb")
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

end



function AirGroup:Destroy()
    Spearhead.DcsUtil.DestroyGroup(self._groupName)
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.airGroups then Spearhead.classes.capClasses.airGroups = {} end
Spearhead.classes.capClasses.airGroups.AirGroup = AirGroup

---@alias GroupState
---| "UnSpawned"
---| "ReadOnTheRamp
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