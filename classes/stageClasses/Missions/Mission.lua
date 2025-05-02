

---@class Mission : OnUnitLostListener
---@field name string 
---@field missionType missionType 
---@field displayMissionType string
---@field code string
---@field priority MissionPriority
---@field location Vec2?
---@field private _state MissionState
---@field private _zoneName string
---@field private _database Database
---@field private _logger Logger 
---@field private _missionBriefing string?
---@field private _missionGroups MissionGroups
---@field private _completeListeners Array<MissionCompleteListener> 
---@field private _missionCommandsHelper MissionCommandsHelper
local Mission = {}

--- @class MissionCompleteListener 
--- @field OnMissionComplete fun(self: any, mission:Mission)

--- @class MissionGroups 
--- @field hasTargets boolean
--- @field groups Array<SpearheadGroup>
--- @field unitsAlive table<string, table<string, boolean>>
--- @field targetsAlive table<string, table<string, boolean>>
--- @field groupNamesPerunit table<string,string>

MINIMAL_UNITS_ALIVE_RATIO = 0.21

---comment
---@param zoneName string
---@param priority MissionPriority
---@param database Database
---@param logger Logger
---@return Mission? 
function Mission.New(zoneName, priority,  database, logger)

    local function ParseZoneName(input)
        local split_name = Spearhead.Util.split_string(input, "_")
        local split_length = Spearhead.Util.tableLength(split_name)
        if Spearhead.Util.startswith(input, "RANDOMMISSION") == true and split_length < 4 then
            Spearhead.AddMissionEditorWarning("Random Mission with zonename " .. input .. " not in right format")
            return nil
        elseif split_length < 3 then
            Spearhead.AddMissionEditorWarning("Mission with zonename" .. input .. " not in right format")
            return nil
        end

        ---@type missionType
        local parsedType = "nil"

        local inputType = string.lower(split_name[2])
        if inputType == "dead" then parsedType = "DEAD" end
        if inputType == "strike" then parsedType = "STRIKE" end
        if inputType == "bai" then parsedType = "BAI" end
        if inputType == "sam" then parsedType = "SAM" end

        if parsedType == "nil" then
            Spearhead.AddMissionEditorWarning("Mission with zonename '" .. input .. "' has an unsupported type '" .. (type or "nil" ))
            return nil
        end
        local name = split_name[3]
        return {
            missionName = name,
            type = parsedType
        }
    end

    local parsed = ParseZoneName(zoneName)

    if parsed == nil then return end

    Mission.__index = Mission
    local o = {}
    local self = setmetatable(o, Mission)
    
    self._zoneName = zoneName
    self.name = parsed.missionName
    self.missionType = parsed.type
    self.displayMissionType = self.missionType or "unknown"
    if self.missionType == "SAM" then self.displayMissionType = "DEAD" end
    self.location = database:GetLocationForMissionZone(zoneName)
    self.code = tostring(database:GetNewMissionCode())
    self.priority = priority
    self._state = "NEW"

    self._logger = logger
    self._database = database
    self._missionCommandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(logger.LogLevel)
    self._completeListeners = {}

    self._missionBriefing = database:getMissionBriefingForMissionZone(zoneName)
    self._missionGroups = {
        groups = {},
        unitsAlive = {},
        targetsAlive = {},
        hasTargets = false,
        groupNamesPerunit = {}
    }

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup
    local groupNames = database:getGroupsForMissionZone(zoneName)
    for _, groupName in pairs(groupNames) do
        
        local spearheadGroup = SpearheadGroup.New(groupName)
        table.insert(self._missionGroups.groups, spearheadGroup)

        local isGroupTarget =Spearhead.Util.startswith(string.lower(groupName), "tgt_")
        for _, unit in pairs(spearheadGroup:GetUnits())do
            local unitName = unit:getName()
            local isUnitTarget = Spearhead.Util.startswith(string.lower(unitName), "tgt_")

            if self._missionGroups.unitsAlive[groupName] == nil then 
                self._missionGroups.unitsAlive[groupName] = {}
            end

            self._missionGroups.unitsAlive[groupName][unitName] = true
            self._missionGroups.groupNamesPerunit[unitName] = groupName

            if isGroupTarget == true or isUnitTarget == true then
                self._missionGroups.hasTargets = true

                if self._missionGroups.targetsAlive[groupName] == nil then
                    self._missionGroups.targetsAlive[groupName] = {}
                end

                self._missionGroups.targetsAlive[groupName][unitName] = true
            end

            Spearhead.Events.addOnUnitLostEventListener(unitName, self)
        end

        Spearhead.DcsUtil.DestroyGroup(groupName)
    end

    return self
end

---comment
---@return MissionState
function Mission:GetState()
    return self._state
end

function Mission:SpawnPersistedState()
    for _, group in pairs(self._missionGroups.groups) do
        group:SpawnCorpsesOnly()
    end
end

function Mission:SpawnActive()

    self._logger:info("Activating " .. self.name)

    self._state = "ACTIVE"
    for _, group in pairs(self._missionGroups.groups) do
        group:Spawn()
    end

    self._missionCommandsHelper:AddMissionToCommands(self)

    self:StartCheckingContinuous()
end

---@private
function Mission:StartCheckingContinuous()
    ---comment
    ---@param mission Mission
    ---@param time any
    ---@return unknown
    local Check = function (mission, time)
        mission:UpdateState(true, true)

        if mission:GetState() == "COMPLETED" then
            return nil
        end
        return time + 30
    end
    timer.scheduleFunction(Check, self, timer.getTime() + 30)
end

---@private
---@return string?
function Mission:ToStateString()
    if self._missionGroups.hasTargets == true then
        local dead = 0
        local total = 0
        if self._missionGroups.targetsAlive then
            for _, group in pairs(self._missionGroups.targetsAlive) do
                for _, isAlive in pairs(group) do
                    total = total + 1
                    if isAlive == false then
                        dead = dead + 1
                    end
                end
            end
        end
        
        if total > 0 then
            local completionPercentage = math.floor((dead / total) * 100)
            return "Targets Destroyed: " .. completionPercentage .. "%"
        end
    else
        local dead = 0
        local total = 0
        if self._missionGroups.unitsAlive then
            for _, group in pairs(self._missionGroups.unitsAlive) do
                for _, isAlive in pairs(group) do
                    total = total + 1
                    if isAlive == false then
                        dead = dead + 1
                    end
                end
            end
        end
       
        if total > 0 then
            local completionPercentage = math.floor((dead / total) * 100)
            return "Units Destroyed: " .. completionPercentage .. "%"
        end
    end
end

---comment
---@param groupId integer
function Mission:ShowBriefing(groupId)

    local stateString = self:ToStateString()

    if self._missionBriefing == nil or self._missionBriefing == ""  then self._missionBriefing = "No briefing available" end
    local text = "Mission [" .. self.code .. "] ".. self.name .. "\n \n" .. self._missionBriefing .. " \n \n" .. stateString
    trigger.action.outTextForGroup(groupId, text, 30);
end


---@param checkHealth boolean
---@param messageIfDone boolean
function Mission:UpdateState(checkHealth, messageIfDone)
    if checkHealth == nil then checkHealth = false end
    if messageIfDone == false then messageIfDone = true end

    if self._state == "COMPLETED" then
        return
    end

    if checkHealth == true then
        local function unitAliveState(unitName)
            local staticObject = StaticObject.getByName(unitName)
            if staticObject then
                if staticObject:isExist() == true then
                    local life0 = staticObject:getDesc().life
                    if staticObject:getLife() / life0 < 0.3 then
                        self._logger:debug("exploding unit")
                        trigger.action.explosion(staticObject:getPoint(), 100)
                        return false
                    end
                    return true
                else
                    return false
                end
            else
                local unit = Unit.getByName(unitName)

                if unit and unit:isExist() then
                    if unit:getLife() / unit:getLife0() < 0.2 then
                        self._logger:debug("exploding unit")
                        trigger.action.explosion(unit:getPoint(), 100)
                        return false
                    end
                    return true
                else
                    return false
                end
            end
        end

        for groupName, unitNameDict in pairs(self._missionGroups.unitsAlive) do
            for unitName, isAlive in pairs(unitNameDict) do
                if isAlive == true then
                    self._missionGroups.unitsAlive[groupName][unitName] = unitAliveState(unitName)
                end
            end
        end

        for groupName, unitNameDict in pairs(self._missionGroups.targetsAlive) do
            for unitName, isAlive in pairs(unitNameDict) do
                if isAlive == true then
                    self._missionGroups.targetsAlive[groupName][unitName] = unitAliveState(unitName)
                end
            end
        end
    end

    if self._missionGroups.hasTargets == true then
        
        local anyTargetAlive = function()
            for _, units in pairs(self._missionGroups.targetsAlive) do
                for _, isAlive in pairs(units) do
                    if isAlive == true then
                        return true
                    end
                end
            end
            return false
        end
        
        if anyTargetAlive() ~= true then
            self._state = "COMPLETED"
        end
    else
        local function CountAliveGroups()
            local aliveGroups = 0

            for _, group in pairs(self._missionGroups.unitsAlive) do
                local groupTotal = 0
                local groupDeath = 0
                for _, isAlive in pairs(group) do
                    if isAlive ~= true then
                        groupDeath = groupDeath + 1
                    end
                    groupTotal = groupTotal + 1
                end

                local aliveRatio = (groupTotal - groupDeath) / groupTotal
                if aliveRatio >= MINIMAL_UNITS_ALIVE_RATIO then
                    aliveGroups = aliveGroups + 1
                end
            end

            return aliveGroups
        end

        if CountAliveGroups() == 0 then
            self._state = "COMPLETED"
        end
    end

    ---comment
    ---@param mission Mission
    local NotifyMissionComplete = function(mission)
        mission:NotifyMissionComplete()
        return nil
    end
    if self._state == "COMPLETED" then
        timer.scheduleFunction(NotifyMissionComplete, self, timer.getTime() + 3)
    end
end

---private usage advised
function Mission:NotifyMissionComplete()

    self._missionCommandsHelper:RemoveMissionToCommands(self)
    self._logger:info("Mission Completed: " .. self._zoneName)
    trigger.action.outText("Mission " .. self.name .. " [" .. self.code .. "] was completed succesfully" , 20)

    for _, listener in pairs(self._completeListeners) do
        pcall(function() 
            listener:OnMissionComplete(self)
        end)
    end
end


---@param listener MissionCompleteListener Object that implements "OnMissionComplete(self, mission)"
function Mission:AddMissionCompleteListener(listener)
    if type(listener) ~= "table" then
        return
    end
    table.insert(self._completeListeners, listener)
end

function Mission:OnUnitLost(object)
    --[[
        OnUnit lost event
    ]]--
    self._logger:debug("Getting on unit lost event")

    local category = Object.getCategory(object)
    if category == Object.Category.UNIT then
        local unitName = object:getName()
        self._logger:debug("UnitName:" .. unitName)

        local groupName = self._missionGroups.groupNamesPerunit[unitName]
        self._missionGroups.unitsAlive[groupName][unitName] = false

        if self._missionGroups.targetsAlive[groupName] and self._missionGroups.targetsAlive[groupName][unitName] then
            self._missionGroups.targetsAlive[groupName][unitName] = false
        end
    elseif category == Object.Category.STATIC  then
        local name = object:getName()
        self._missionGroups.unitsAlive[name][name] = false

        self._logger:debug("Name " .. name)

        if self._missionGroups.targetsAlive[name] and self._missionGroups.targetsAlive[name][name] then
            self._missionGroups.targetsAlive[name][name] = false
        end
    end
    self:UpdateState(false, true)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Missions then Spearhead.classes.stageClasses.Missions = {} end
Spearhead.classes.stageClasses.Missions.Mission = Mission


