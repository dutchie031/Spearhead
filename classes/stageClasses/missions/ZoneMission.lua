--- ZoneMission is missions that are defined by zones in the ME
---@class ZoneMission : Mission, OnUnitLostListener
---@field private _state MissionState
---@field private _missionGroups MissionGroups
---@field private _dependencies table<string, boolean>
---@field private _completeAtIndex number
---@field private _parentStage Stage
---@field private _battleManager? BattleManager
local ZoneMission = {}

--- @class MissionGroups
--- @field hasTargets boolean
--- @field redGroups Array<SpearheadGroup>
--- @field blueGroups Array<SpearheadGroup>
--- @field unitsAlive table<string, table<string, boolean>>
--- @field targetsAlive table<string, table<string, boolean>>
--- @field groupNamesPerunit table<string,string>

---@class ParsedMissionName
---@field missionName string
---@field type MissionType

---comment
---@param input string
---@return ParsedMissionName?
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

    ---@type MissionType
    local parsedType = "nil"

    local inputType = string.lower(split_name[2])
    if inputType == "dead" then parsedType = "DEAD" end
    if inputType == "strike" then parsedType = "STRIKE" end
    if inputType == "cas" then parsedType = "CAS" end
    if inputType == "bai" then parsedType = "BAI" end
    if inputType == "sam" then parsedType = "SAM" end

    if parsedType == "nil" then
        Spearhead.AddMissionEditorWarning("Mission with zonename '" ..
            input .. "' has an unsupported type '" .. (type or "nil"))
        return nil
    end
    local name = split_name[3]
    return {
        missionName = name,
        type = parsedType
    }
end

MINIMAL_UNITS_ALIVE_RATIO = 0.21

---comment
---@param zoneName string
---@param priority MissionPriority
---@param database Database
---@param logger Logger
---@param parentStage Stage
---@return ZoneMission?
function ZoneMission.new(zoneName, priority, database, logger, parentStage)
    local Mission = Spearhead.classes.stageClasses.missions.baseMissions.Mission
    ZoneMission.__index = ZoneMission
    setmetatable(ZoneMission, Mission)

    local self = setmetatable({}, ZoneMission)

    local parsed = ParseZoneName(zoneName)
    if not parsed then
        logger:error("Failed to create ZoneMission " .. zoneName .. " => invalid name")
        return nil
    end

    local missionBriefing = database:getMissionBriefingForMissionZone(zoneName) or "no briefing provided"

    local success, error = Mission.newSuper(self, zoneName, parsed.missionName, parsed.type, missionBriefing, priority,
        database, logger)
    if not success then
        logger:error("Failed to create ZoneMission " .. zoneName .. " => " .. error)
        return nil
    end

    --- parent new done

    if self.missionType == "SAM" then
        self.missionTypeDisplay = "DEAD"
    end

    self._missionGroups = {
        redGroups = {},
        blueGroups = {},
        unitsAlive = {},
        targetsAlive = {},
        hasTargets = false,
        groupNamesPerunit = {}
    }

    self._parentStage = parentStage
    self._dependencies = {}

    local dependencies = database:getMissionDependencies(zoneName)
    for _, dependency in pairs(dependencies) do
        self._dependencies[dependency] = false
    end

    local completeAtIndex = database:getMissionCompleteAt(zoneName)
    if completeAtIndex == nil and self.missionType == "BAI" or self.missionType == "CAS" then
        self._completeAtIndex = 0.8
    elseif completeAtIndex == nil then
        self._completeAtIndex = 1
    else
        self._completeAtIndex = completeAtIndex
    end

    self._logger:debug("Complete at index " .. self.zoneName .. ": " .. self._completeAtIndex)

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup

    local missionData = database:getMissionDataForZone(zoneName)
    if not missionData then return end

    for _, groupName in pairs(missionData.BlueGroups) do
        local spearheadGroup = SpearheadGroup.New(groupName)
        if spearheadGroup then
            table.insert(self._missionGroups.blueGroups, spearheadGroup)
        end
        spearheadGroup:Destroy()
    end

    for _, groupName in pairs(missionData.RedGroups) do
        local spearheadGroup = SpearheadGroup.New(groupName)
        table.insert(self._missionGroups.redGroups, spearheadGroup)

        local isGroupTarget = Spearhead.Util.startswith(string.lower(groupName), "tgt_")
        for _, unit in pairs(spearheadGroup:GetObjects()) do
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

        spearheadGroup:Destroy()
    end

    if self.missionType == "CAS" then
        self._battleManager = Spearhead.classes.stageClasses.helpers.BattleManager.New(self._missionGroups.redGroups, self._missionGroups.blueGroups, self.zoneName, self._logger.LogLevel)

    end

    self._logger:debug("Mission " .. self.name .. " group count: " .. Spearhead.Util.tableLength(missionData.RedGroups))

    return self
end

---@private
function ZoneMission:StartCheckingDependencies()
    self._state = "WAITING"

    ---comment
    ---@param mission ZoneMission
    ---@param time any
    ---@return unknown
    local function CheckDependencies(mission, time)
        if mission:AllDependenciesMet() == true then
            mission:SpawnActive()
            return nil
        end

        return time + 15
    end

    timer.scheduleFunction(CheckDependencies, self, timer.getTime() + 15)
end

---@return boolean
function ZoneMission:AllDependenciesMet()
    local allDependenciesMet = true
    for missionName, value in pairs(self._dependencies) do
        if self._parentStage:IsMissionComplete(missionName) == false then
            allDependenciesMet = false
            self._dependencies[missionName] = false
        else
            self._dependencies[missionName] = true
        end
    end

    if allDependenciesMet == true then
        self._logger:info("All dependencies met for " .. self.name)
    end

    return allDependenciesMet
end

---@internal
---@param checkHealth boolean
---@param messageIfDone boolean
function ZoneMission:UpdateState(checkHealth, messageIfDone)
    if checkHealth == nil then checkHealth = false end
    if messageIfDone == false then messageIfDone = true end


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

        if self._missionGroups.hasTargets == true then
            for groupName, unitNameDict in pairs(self._missionGroups.targetsAlive) do
                for unitName, isAlive in pairs(unitNameDict) do
                    if isAlive == true then
                        self._missionGroups.targetsAlive[groupName][unitName] = unitAliveState(unitName)
                    end
                end
            end
        else
            for groupName, unitNameDict in pairs(self._missionGroups.unitsAlive) do
                for unitName, isAlive in pairs(unitNameDict) do
                    if isAlive == true then
                        self._missionGroups.unitsAlive[groupName][unitName] = unitAliveState(unitName)
                    end
                end
            end
        end
    end

    if self._missionGroups.hasTargets == true then
        local total = 0
        local alive = 0

        for _, units in pairs(self._missionGroups.targetsAlive) do
            for _, isAlive in pairs(units) do
                total = total + 1
                if isAlive == true then
                    alive = alive + 1
                end
            end
        end

        local deadRatio = (total - alive) / total
        if deadRatio >= self._completeAtIndex then
            self._logger:debug("Dead ratio " .. self.zoneName .. deadRatio .. " >= " .. self._completeAtIndex)
            self._state = "COMPLETED"
        end
    else
        local total = 0
        local alive = 0

        for _, units in pairs(self._missionGroups.unitsAlive) do
            for _, isAlive in pairs(units) do
                total = total + 1
                if isAlive == true then
                    alive = alive + 1
                end
            end
        end

        local deadRatio = (total - alive) / total
        if deadRatio >= self._completeAtIndex then
            self._logger:debug("Dead ratio " .. self.zoneName .. deadRatio .. " >= " .. self._completeAtIndex)

            self._state = "COMPLETED"
        end
    end

    if self._state == "COMPLETED" and self._battleManager then
        self._battleManager:Stop()
    end
end

function ZoneMission:SpawnPersistedState()
    for _, group in pairs(self._missionGroups.redGroups) do
        group:Spawn()
    end
end

---spawns the mission, but doesn't add
function ZoneMission:SpawnInactive()
    self._logger:info("PreActivating " .. self.name)

    for _, group in pairs(self._missionGroups.redGroups) do
        group:Spawn()
    end
end

function ZoneMission:SpawnActive()
    if self:AllDependenciesMet() == false then
        self:SpawnInactive()
        self:StartCheckingDependencies()
        return
    end

    self._logger:info("Activating " .. self.name)

    if self._state == "COMPLETED" or self._state == "ACTIVE" then
        self._logger:debug("Mission already completed, not spawning")
        return
    end

    self._state = "ACTIVE"
    for _, group in pairs(self._missionGroups.redGroups) do
        group:Spawn()
    end

    for _, group in pairs(self._missionGroups.blueGroups) do
        group:Spawn()
    end

    if self._battleManager then
        self._battleManager:Start()
    end

    self._missionCommandsHelper:AddMissionToCommands(self)

    self:StartCheckingContinuous()
end

---@private
function ZoneMission:StartCheckingContinuous()
    ---comment
    ---@param mission Mission
    ---@param time any
    ---@return unknown
    local Check = function(mission, time)
        mission:UpdateState(true, true)

        if mission:getState() == "COMPLETED" then
            mission:NotifyMissionComplete()
            return nil
        end
        return time + 30
    end
    timer.scheduleFunction(Check, self, timer.getTime() + 30)
end

---@protected
function ZoneMission:ToStateString()
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

function ZoneMission:OnUnitLost(object)
    --[[
        OnUnit lost event
    ]] --
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
    elseif category == Object.Category.STATIC then
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
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.ZoneMission = ZoneMission
