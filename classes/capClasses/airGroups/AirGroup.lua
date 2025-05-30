

---@class AirGroup : OnUnitLostListener
---@field private _groupName string
---@field private _groupType AirGroupType
---@field private _state GroupState
---@field private _isSpawned boolean
---@field private _config CapConfig
---@field private _checkLivenessNumber number
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

---@param selfA AirGroup
local function RearmDelayed(selfA)
    AirGroup:RearmComplete()
end

function AirGroup:RearmComplete()
    if self._state == "Rearming" then
        self:SetState("ReadOnTheRamp")
    end
end

function AirGroup:Spawn()
    if self._isSpawned then return end

    local group, isStatic = Spearhead.DcsUtil.SpawnGroupTemplate(self._groupName, nil, nil, true)
    if group then
        self._group = group
        self._isSpawned = true
        self._initialSize = #group:getUnits()
        self._liveState = {}
    else
        Spearhead.DcsUtil.LogError("Failed to spawn group: " .. self._groupName)
    end

    if self._state == "UnSpawned" then
        self._state = "ReadOnTheRamp"
    else 
        self._state = "Rearming"
        timer.scheduleFunction(RearmDelayed, self, timer.getTime() + self._config)
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

---@protected
---@param state GroupState
function AirGroup:SetState(state)
    self._state = state
end

---@return number? timeInterval
function AirGroup:CheckLiveness()

    local isAlive = false
    local group = Group.getByName(self._groupName)

    if group and group:isExist()  then
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() and unit:getLife() > (unit:getLife0() * 0.3) then
                isAlive = true
            end
        end
    end

    if isAlive == false then
        self:SetState("Dead")
        return nil
    end

    return 5
end

do --EVENT LISTENERS

    ---@param unit Unit
    function AirGroup:OnUnitLost(unit)

    end


    function AirGroup:OnGroupRTBInTen(groupName)
        self:SetState("RtbInTen")
    end

    function AirGroup:OnGroupRTB(groupName)
        self:SetState("Rtb")
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
---| "Rearming"


---@alias AirGroupType
---| "CAP"

---| "CAS"
---| "SEAD"
---| "INTERCEPT"
---| ""