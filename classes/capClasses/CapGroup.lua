

local CapHelper = {}
do
    ---comment
    ---@param groupName string
    ---@return table?
    CapHelper.ParseGroupName = function(groupName)
        local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then
            local result = {}
            result.zonesConfig = {}

            -- CAP_[1-5]5|[6]6|[7]7_Sukhoi
            -- CAP_[1-5,7]A|[6]7_Sukhoi

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "A" then
                result.isBackup = false
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "B" then
                configPart = string.sub(configPart, 2, #configPart)
                result.isBackup = true
            elseif first == "[" then
                result.isBackup = false
            else
                Spearhead.AddMissionEditorWarning("Could not parse the CAP config for group: " .. groupName)
                return nil
            end

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
                                if targetZone == "A" then
                                    result.zonesConfig[tostring(i)] = tostring(i)
                                else
                                    result.zonesConfig[tostring(i)] = tostring(targetZone)
                                end
                            end
                        else
                            if targetZone == "A" then
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(dashSeperated[1])
                            else
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(targetZone)
                            end
                        end
                    end
                end
            end
            return result
        else
            Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
    end
end

---comment
---@param input table { groupName, task, logger }
---@param time number
---@return nil
local function setTaskAsync(input, time)
    local task = input.task
    local groupName = input.groupName
    local group = Group.getByName(groupName)

    if task and group then
        group:getController():setTask(task)
        if input.logger ~= nil then
            input.logger:debug("task set succesfully to group " .. groupName)
        end
    end
    return nil
end


---@class OnUpdateListener
---@field onGroupStateUpdated fun(self: OnUpdateListener, capGroup: CapGroup)

---@class CapGroup : OnUnitLostListener
---@field isBackup boolean
---@field groupName string
---@field assignedStageNumber string    
---@field private airbaseName string
---@field private logger Logger
---@field private database Database
---@field private capConfig table
---@field private capZonesConfig table<string, string>
---@field private aliveUnits table<string, boolean>
---@field private onStatusUpdatedListener Array<OnUpdateListener>
local CapGroup = {}

CapGroup.GroupState = {
    UNSPAWNED = 0,
    READYONRAMP = 1,
    INTRANSIT = 2,
    ONSTATION = 3,
    RTBINTEN = 4,
    RTB = 5,
    DEAD = 6,
    REARMING = 7
}

local function SetReadyOnRampAsync(self, time)
    self:SetState(CapGroup.GroupState.READYONRAMP)
end

local RESPAWN_AFTER_TOUCHDOWN_SECONDS = 180

---comment
---@param groupName string
---@param airbaseName string
---@param logger Logger logger dependency injection
---@param database Database database  dependency injection
---@param capConfig table config dependency injection
---@return CapGroup? self
function CapGroup.new(groupName, airbaseName, logger, database, capConfig)

    CapGroup.__index = CapGroup
    local self = setmetatable({}, CapGroup)

    Spearhead.DcsUtil.DestroyGroup(groupName)

    -- initials
    self.groupName = groupName
    self.airbaseName = airbaseName

    local airbase = Airbase.getByName(airbaseName)
    if airbase == nil then
        logger:error("Airbase with name " .. airbaseName .. " does not exist")
        return nil
    end

    self.airbaseId = airbase:getID()
    self.logger = logger
    self.database = database

    local parsed = CapHelper.ParseGroupName(groupName)
    if parsed == nil then return nil end
    self.capZonesConfig = parsed.zonesConfig
    self.isBackup = parsed.isBackup

    --vars
    self.assignedStageNumber = nil
    
    self.state = CapGroup.GroupState.UNSPAWNED
    self.aliveUnits = {}
    self.landedUnits = {}
    self.unitCount = 0
    self.onStationSince = 0
    self.currentCapTaskingDuration = 0
    self.markedForDespawn = false

    self.onStatusUpdatedListener = {}

    --config
    self.capConfig = capConfig

    Spearhead.Events.addOnGroupRTBListener(self.groupName, self)
    Spearhead.Events.addOnGroupRTBInTenListener(self.groupName, self)
    Spearhead.Events.addOnGroupOnStationListener(self.groupName, self)
    local units = Group.getByName(groupName):getUnits()
    for key, unit in pairs(units) do
        Spearhead.Events.addOnUnitLandEventListener(unit:getName(), self)
        Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
    end

    return self
end

---@param currentActive number
---@return string
function CapGroup:GetTargetZone(currentActive)
    return self.capZonesConfig[tostring(currentActive)]
end

function CapGroup:SetState(state)
    self.state = state
    self:PublishUnitUpdatedEvent()
end

function CapGroup:StartRearm()
    self:SpawnOnTheRamp()
    self:SetState(CapGroup.GroupState.REARMING)
    timer.scheduleFunction(SetReadyOnRampAsync, self, timer.getTime() + self.capConfig:getRearmDelay() - RESPAWN_AFTER_TOUCHDOWN_SECONDS)
end

function CapGroup:SpawnOnTheRamp()
    self.markedForDespawn = false
    self.logger:debug("Spawning group " .. self.groupName)
    self.aliveUnits = {}
    self.landedUnits = {}
    self.onStationSince = 0

    local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName, nil, nil, true)
    if group then
        self.unitCount = group:getInitialSize()

        if self.state == CapGroup.GroupState.UNSPAWNED then
            self:SetState(CapGroup.GroupState.READYONRAMP)
        end

        for _, unit in pairs(group:getUnits()) do
            local name = unit:getName()
            self.aliveUnits[name] = true
            self.landedUnits[name] = false
        end
    end
end

function CapGroup:Despawn()
    self.logger:debug("Despawning group " .. self.groupName)
    Spearhead.DcsUtil.DestroyGroup(self.groupName)
    self:SetState(CapGroup.GroupState.UNSPAWNED)
end

function CapGroup:SendRTB()
    local group = Group.getByName(self.groupName)
    if group and group:isExist() then
        local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
        local rtbTask, errormessage = Spearhead.RouteUtil.CreateRTBMission(self.groupName, self.airbaseId, speed)
        if rtbTask then
            timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
        else
            self.logger:error("No RTB task could be created for group: " .. self.groupName .. " due to " .. errormessage)
            if self.markedForDespawn == true then
                self:Despawn()
            end
        end
    end
end

function CapGroup:SendRTBAndDespawn()
    self.markedForDespawn = true
    self:SendRTB()
end

---@param stageZoneNumber string
function CapGroup:SendToStage(stageZoneNumber)
    if self.state == CapGroup.GroupState.DEAD or self.state == CapGroup.GroupState.RTB then
        return --Can't task a unit that's dead or RTB
    end

    self.assignedStageNumber = stageZoneNumber
    local group = Group.getByName(self.groupName)
    if group and group:isExist() then
        self.logger:debug("Sending group out " .. self.groupName)
        local controller = group:getController()
        local capPoints = self.database:getCapRouteInZone(stageZoneNumber, self.airbaseName)

        local altitude = math.random(self.capConfig:getMinAlt(), self.capConfig:getMaxAlt())
        local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
        local attackHelos = false
        local deviationDistance = self.capConfig:getMaxDeviationRange()
        local capTask
        if self.state == CapGroup.GroupState.ONRAMP or self.onStationSince == 0 then
            controller:setCommand({
                id = 'Start',
                params = {}
            })
            local duration = math.random(self.capConfig:getMinDurationOnStation(), self.capConfig:getmaxDurationOnStation())
            self.currentCapTaskingDuration = duration

            
            capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
        else
            local duration = self.currentCapTaskingDuration - (timer.getTime() - self.onStationSince)
            capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
        end

        if capTask then
            timer.scheduleFunction(setTaskAsync,
                { task = capTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
        end
        self:SetState(CapGroup.GroupState.INTRANSIT)
    end
end

---@param airdomeId any
function CapGroup:SendToAirbase(airdomeId)
    self.airbaseId = airdomeId
    local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
    local rtbTask = Spearhead.RouteUtil.CreateRTBMission(self.groupName, airdomeId, speed)
    local group = Group.getByName(self.groupName)

    if not group then return end
    local controller = group:getController()
    controller:setCommand({
        id = 'Start',
        params = {}
    })
    timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger },
        timer.getTime() + 5)
end

function CapGroup:OnGroupRTB(groupName)
    if groupName == self.groupName then
        self.logger:debug("Setting group " .. 
        groupName ..
        " to state RTB after a total of " ..
        timer.getTime() - self.onStationSince .. "s of the " .. self.currentCapTaskingDuration .. "s")
        self:SetState(CapGroup.GroupState.RTB)
    end
end

function CapGroup:OnGroupRTBInTen(groupName)
    if groupName == self.groupName then
        self:SetState(CapGroup.GroupState.RTBINTEN)
    end
end

function CapGroup:OnGroupOnStation(groupName)
    if groupName == self.groupName then
        self.onStationSince = timer.getTime()
        self.logger:debug("Setting group " .. groupName .. " to state Onstation")
        self:SetState(CapGroup.GroupState.ONSTATION)
    end
end

    
---@param proActive boolean Will check all units in group for aliveness
function CapGroup:UpdateState(proActive)
    local landed = false
    local landedCount = 0
    for name, landedBool in pairs(self.landedUnits) do
        if landedBool == true then
            landedCount = landedCount + 1
            landed = true
        end
    end

    local deadCount = 0
    for name, isAlive in pairs(self.aliveUnits) do
        if isAlive == false then
            deadCount = deadCount + 1
        end
    end

    local function DelayedStartRearm(input, time)
        local capGroup = input.self
        capGroup:StartRearm()
    end

    if landedCount + deadCount == self.unitCount then
        if landed then
            if self.markedForDespawn == true then
                self:Despawn()
            else
                timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + RESPAWN_AFTER_TOUCHDOWN_SECONDS)
            end
        else
            if self.markedForDespawn == true then
                self:Despawn()
            else
                local delay = self.capConfig:getDeathDelay() - self.capConfig:getRearmDelay() + RESPAWN_AFTER_TOUCHDOWN_SECONDS
                timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + delay)
            end
        end
    end
end


---@param listener table object with  function OnGroupStateUpdated(capGroupTable)
function CapGroup:AddOnStateUpdatedListener(listener)
    if type(listener) ~= "table" then
        self.logger:error("Listener not of type table for AddOnStateUpdatedListener")
        return
    end

    if listener.onGroupStateUpdated == nil then
        self.logger:error("Listener does not implement onGroupStateUpdated")
        return
    end
    table.insert(self.onStatusUpdatedListener, listener)
end

function CapGroup:PublishUnitUpdatedEvent()
    for _, callable in pairs(self.onStatusUpdatedListener) do
        local _, error = pcall(function()
            callable:onGroupStateUpdated(self)
        end)
        if error then
            self.logger:error(error)
        end
    end
end

function CapGroup:OnUnitLanded(initiatorUnit, airbase)
    if airbase then
        self.airbaseName = airbase:getName()
    end
    local name = initiatorUnit:getName()
    self.logger:debug("Received unit land event for unit " .. name .. " of group " .. self.groupName)

    self.landedUnits[name] = true
    self:UpdateState(false)
end

function CapGroup:OnUnitLost(initiatorUnit)
    self.logger:debug("Received unit lost event for group " .. self.groupName)
    if initiatorUnit then
        self.aliveUnits[initiatorUnit:getName()] = false
    end
    self:UpdateState(false)
end


if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.CapGroup = CapGroup
