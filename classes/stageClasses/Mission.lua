
--- A mission Object.
local Mission = {}
do -- INIT Mission Class

    local MINIMAL_UNITS_ALIVE_RATIO = 0.20

    local Defaults = {}
    Defaults.MainMenu = "Missions"
    Defaults.SelectMenuSubMenus = { Defaults.MainMenu, "Select Mission" }
    Defaults.ShowMissionSubs = { Defaults.MainMenu }

    local PlayersInMission = {}

    local MissionTypeParser = {}
    do --INIT MISSION TYPE FUNCTIONS
        ---Parse string to mission type
        ---@param input string
        ---@return missionType missionType
        MissionTypeParser.Parse = function(input)
            if input == nil then
                return Mission.MissionType.UNKNOWN
            end

            input = string.lower(input)
            if input == "dead" then return "DEAD" end
            if input == "strike" then return "STRIKE" end
            if input == "bai" then return "BAI" end
            if input == "sam" then return "SAM" end
            return "nil"
        end

        ---comment
        ---@param input missionType missionType
        ---@return string text
        MissionTypeParser.toString = function(input)
            if input == "DEAD" then return "DEAD" end
            if input == "STRIKE" then return "STRIKE" end
            if input == "BAI" then return "BAI" end
            if input == "SAM" then return "SAM" end
            return "?"
        end
    end
    Mission.MissionTypeParser = MissionTypeParser

    --- @class MissionCompleteListener 
    --- @field OnMissionComplete fun(self: any, mission:Mission)

    --- @class Mission missionClass
    --- @field missionZoneName string
    --- @field name string
    --- @field missionType missionType  
    --- @field missionState missionState
    --- @field code string
    --- @field priority missionPriority
    --- @field GetState fun(self:Mission):missionState
    --- @field AddMissionCompleteListener fun(self:Mission, listener:MissionCompleteListener) Object that implements "OnMissionComplete(self, mission)"
    --- @field SpawnsPersistedState fun(self:Mission) Activate groups (if not spawned before) and spawn corpses where needed.
    --- @field Activate fun(self:Mission) Activate groups for this mission
    --- @field ShowBriefing fun(self:Mission, groupId:integer)

    ---comment
    ---@param missionZoneName string missionZoneName
    ---@param priority missionPriority missionPriority
    ---@param database table db dependency injection
    ---@return Mission? o
    function Mission:new(missionZoneName, priority, database, logger)
        local o = {}
        setmetatable(o, { __index = self })

        local function ParseGroupName(input)
            local split_name = Spearhead.Util.split_string(input, "_")
            local split_length = Spearhead.Util.tableLength(split_name)
            if Spearhead.Util.startswith(input, "RANDOMMISSION") == true and split_length < 4 then
                Spearhead.AddMissionEditorWarning("Random Mission with zonename " .. input .. " not in right format")
                return nil
            elseif split_length < 3 then
                Spearhead.AddMissionEditorWarning("Mission with zonename" .. input .. " not in right format")
                return nil
            end
            local type = split_name[2]
            local parsedType = Mission.MissionTypeParser.Parse(type)
    
            if parsedType == nil then
                Spearhead.AddMissionEditorWarning("Mission with zonename '" .. input .. "' has an unsupported type '" .. (type or "nil" ))
                return nil
            end
            local name = split_name[3]
            return {
                missionName = name,
                type = parsedType
            }
        end

        local parsed = ParseGroupName(missionZoneName)
        if parsed == nil then return nil end


        --public fields
        o.missionZoneName = missionZoneName
        o.name = parsed.missionName
        o.missionType = parsed.type
        ---@type missionState
        o.missionState = "NEW"
        o.priority = priority
        o.code = database:GetNewMissionCode()

        --private fields
        o._database = database
        o.groupNames = database:getGroupsForMissionZone(missionZoneName)
        o.startingGroups = Spearhead.Util.tableLength(o.groupNames)
        o.startingUnits = 0
        o.logger = logger
        o.missionbriefing = database:GetDescriptionForMission(missionZoneName)
        o.groupNamesPerUnit = {}

        o.groupUnitAliveDict = {}
        o.targetAliveStates = {}
        o.hasSpecificTargets = false

        o.spawnedGroups = {}

        local CheckStateAsync = function (self, time)
            self:CheckAndUpdateSelf()
            return nil
        end

        o.GetState = function(self)
            return self.missionState
        end

        o.OnUnitLost = function(self, object)
            --[[
                OnUnit lost event
            ]]--
            self.logger:debug("Getting on unit lost event")

            pcall(function ()
                local name = object:getName()
                local pos = object:getPoint()
                local type = object:getDesc().typeName
                local position = object:getPosition()
                local heading = math.atan2(position.x.z, position.x.x)
                local country_id = object:getCountry()
                Spearhead.classes.persistence.Persistence.UnitKilled(name, pos, heading, type, country_id)
            end)

            local category = Object.getCategory(object)
            if category == Object.Category.UNIT then
                local unitName = object:getName()
                self.logger:debug("UnitName:" .. unitName)
                local groupName = self.groupNamesPerUnit[unitName]
                self.groupUnitAliveDict[groupName][unitName] = false

                if self.targetAliveStates[groupName][unitName] then
                    self.targetAliveStates[groupName][unitName] = false
                end
            elseif category == Object.Category.STATIC  then
                local name = object:getName()
                self.groupUnitAliveDict[name][name] = false

                self.logger:debug("Name " .. name)

                if self.targetAliveStates[name][name] then
                    self.targetAliveStates[name][name] = false
                end
            end
            timer.scheduleFunction(CheckStateAsync, self, timer.getTime() + 1)
        end

        o.MissionCompleteListeners = {}
        ---comment
        ---@param self table
        ---@param listener table Object that implements "OnMissionComplete(self, mission)"
        o.AddMissionCompleteListener = function(self, listener)
            if type(listener) ~= "table" then
                return
            end
            
            table.insert(self.MissionCompleteListeners, listener)
        end

        local TriggerMissionComplete = function(self)
            for _, callable in pairs(self.MissionCompleteListeners) do
                local succ, err = pcall( function() 
                    callable:OnMissionComplete(self)
                end)
                if err then
                    self.logger:warn("Error in misstion complete listener:" .. err)
                end
            end
        end


        local StartCheckingAndUpdateSelfContinuous = function (self)
            local CheckAndUpdate = function(self, time)
                self:CheckAndUpdateSelf(true)
                if self.missionState == Mission.MissionState.COMPLETED or self.missionState == Mission.MissionState.NEW then
                    return nil
                else
                    return time + 5                end
            end

            timer.scheduleFunction(CheckAndUpdate, self, timer.getTime() + 5)
        end

        ---comment
        ---@param self table
        ---@param checkUnitHealth boolean?
        o.CheckAndUpdateSelf = function(self, checkUnitHealth, displayMessageIfDone)
            if not checkUnitHealth then checkUnitHealth = false end
            if displayMessageIfDone == nil then displayMessageIfDone = true end

            if checkUnitHealth == true then
                local function unitAliveState(unitName)


                    local staticObject = StaticObject.getByName(unitName)
                    if staticObject then
                        if staticObject:isExist() == true then
                            local life0 = staticObject:getDesc().life
                            if staticObject:getLife() / life0 < 0.3 then
                                self.logger:info("exploding unit")
                                trigger.action.explosion(staticObject:getPoint(), 100)
                                return false
                            end
                            return true
                        else
                            return false
                        end
                    else
                        local unit = Unit.getByName(unitName)

                        local alive = unit ~= nil and unit:isExist() == true
                        if alive == true then
                            if unit:getLife() / unit:getLife0() < 0.2 then
                                self.logger:info("exploding unit")
                                trigger.action.explosion(unit:getPoint(), 100)
                                return false
                            end
                            return true
                        else
                            return false
                        end
                    end
                end

                for groupName, unitNameDict in pairs(self.groupUnitAliveDict) do
                    for unitName, isAlive in pairs(unitNameDict) do
                        if isAlive == true then
                            self.groupUnitAliveDict[groupName][unitName] = unitAliveState(unitName)
                        end
                    end
                end

                for groupName, unitNameDict in pairs(self.targetAliveStates) do
                    for unitName, isAlive in pairs(unitNameDict) do
                        if isAlive == true then
                            self.targetAliveStates[groupName][unitName] = unitAliveState(unitName)
                        end
                    end
                end
            end

            if self.missionState == Mission.MissionState.COMPLETED then
                return
            end

            if self.hasSpecificTargets == true then
                local specificTargetsAlive = false
                for groupName, unitNameDict in pairs(self.targetAliveStates) do
                    for unitName, isAlive in pairs(unitNameDict) do
                        if isAlive == true then
                            specificTargetsAlive = true
                        end
                    end
                end
                if specificTargetsAlive == false then
                    self.missionState = Mission.MissionState.COMPLETED
                end
            else
                local function CountAliveGroups()
                    local aliveGroups = 0

                    for _, group in pairs(self.groupUnitAliveDict) do
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
                
                if self.missionType == Mission.MissionType.STRIKE then --strike targets should normally have TGT targets
                    if CountAliveGroups() == 0 then
                        self.missionState = Mission.MissionState.COMPLETED
                    end
                elseif self.missionType == Mission.MissionType.BAI then
                    if CountAliveGroups() == 0 then
                        self.missionState = Mission.MissionState.COMPLETED
                    end
                end
                --[[
                    TODO: Other checks for mission complete 
                ]]
            end

            if self.missionState == Mission.MissionState.COMPLETED then
                self.logger:debug("Mission complete " .. self.name)

                if displayMessageIfDone == true then
                    trigger.action.outText("Mission " .. self.name .. " (" .. self.code .. ") was completed succesfully!", 20)
                end

                TriggerMissionComplete(self)
                --Schedule cleanup after 5 minutes of mission complete
                --timer.scheduleFunction(CleanupDelayedAsync, self, timer.getTime() + 300)
            end
        end

        o.spawnedPersisted = false
        ---Spawns all corpses and alive units as in the persistance state
        ---@param self table
        o.SpawnsPersistedState = function(self)
            if self.spawnedPersisted == true then
                return 
            end
            
            for groupName, unitNames in pairs(self.groupUnitAliveDict) do
                if self.spawnedGroups[groupName] ~= true then
                    Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    self.spawnedGroups[groupName] = true
                    for unitName, isAlive in pairs(unitNames) do
                        local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                            if deathState.isCleaned == false then
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                            end
                            
                            self.groupUnitAliveDict[groupName][unitName] = false
                            if self.targetAliveStates[groupName][unitName] == true then
                                self.targetAliveStates[groupName][unitName] = false
                            end
                        end
                    end
                end
            end

            self.spawnedPersisted = true
        end

        ---Activates groups for this mission
        ---@param self table
        o.Activate = function(self)
            if self.missionState == Mission.MissionState.ACTIVE then
                return
            end

            self.missionState = Mission.MissionState.ACTIVE

            if self.spawnedPersisted == false then
                
                do --Check Persistence
                    local needsChecking = false
                    for groupName, unitNames in pairs(self.groupUnitAliveDict) do
                        if self.spawnedGroups[groupName] ~= true then
                            Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                            self.spawnedGroups[groupName] = true
                            for unitName, isAlive in pairs(unitNames) do
                                local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                                if deathState and deathState.isDead == true then
                                    Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                                    if deathState.isCleaned == false then
                                        Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                                    end
                                    
                                    self.groupUnitAliveDict[groupName][unitName] = false
                                    needsChecking = true
                                    if self.targetAliveStates[groupName][unitName] == true then
                                        self.targetAliveStates[groupName][unitName] = false
                                    end
                                end
                            end
                        end
                    end
    
                    if needsChecking == true then
                        self:CheckAndUpdateSelf(false, false)
                    end
                end
            end

            StartCheckingAndUpdateSelfContinuous(self)
        end

        local ToStateString = function(self)
            if self.hasSpecificTargets then
                local dead = 0
                local total = 0
                for _, group in pairs(self.targetAliveStates) do
                    for _, isAlive in pairs(group) do
                        total = total + 1
                        if isAlive == false then
                            dead = dead + 1
                        end
                    end
                end
                local completionPercentage = math.floor((dead / total) * 100)
                return "Targets Destroyed: " .. completionPercentage .. "%"
            else
                local dead = 0
                local total = 0
                for _, group in pairs(self.groupUnitAliveDict) do
                    for _, isAlive in pairs(group) do
                        total = total + 1
                        if isAlive == false then
                            dead = dead + 1
                        end
                    end
                end

                local completionPercentage = math.floor((dead / total) * 100)
                return "Targets Destroyed: " .. completionPercentage .. "%"
            end
        end

        o.ShowBriefing = function(self, groupId)
            local stateString = ToStateString(self)

            if self.missionbriefing == nil then self.missionbriefing = "No briefing available" end
            local text = "Mission [" .. self.code .. "] ".. self.name .. "\n \n" .. self.missionbriefing .. " \n \n" .. stateString
            trigger.action.outTextForGroup(groupId, text, 30);
        end

        o.Cleanup = function(self)
            for key, groupName in pairs(self.groupNames) do
                Spearhead.DcsUtil.DestroyGroup(groupName)
            end
        end

        
        local Init = function(self)
            for key, group_name in pairs(self.groupNames) do


                self.groupUnitAliveDict[group_name] = {}
                self.targetAliveStates[group_name] = {}

                if Spearhead.DcsUtil.IsGroupStatic(group_name) then
                    Spearhead.Events.addOnUnitLostEventListener(group_name, self)

                    self.groupUnitAliveDict[group_name][group_name] = true

                    if Spearhead.Util.startswith(group_name, "TGT_") == true then
                        self.targetAliveStates[group_name][group_name] = true
                        self.hasSpecificTargets = true
                    end
                else
                    local group = Group.getByName(group_name)
                    local isGroupTarget = Spearhead.Util.startswith(group_name, "TGT_")

                    self.startingUnits = self.startingUnits + group:getInitialSize()
                    for _, unit in pairs(group:getUnits()) do
                        
                        local unitName = unit:getName()
                        self.groupUnitAliveDict[group_name][unitName] = true

                        self.groupNamesPerUnit[unitName] = group_name

                        Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                        
                        if isGroupTarget == true or Spearhead.Util.startswith(unitName, "TGT_") == true then
                            self.targetAliveStates[group_name][unitName] = true
                            self.hasSpecificTargets = true
                        end

                        if self.missionType == MissionType.BAI then
                            if Spearhead.DcsUtil.IsGroupStatic(group_name) ~= true then
                                self.groupUnitAliveDict[group_name][unitName] = true
                            end
                        elseif self.missionType == MissionType.DEAD or self.missionType == MissionType.SAM then
                            local desc = unit:getDesc()
                            local attributes = desc.attributes
                            if attributes["SAM"] == true or attributes["SAM TR"] or attributes["AAA"] then
                                self.targetAliveStates[group_name][unitName] = true
                                self.hasSpecificTargets = true
                            end
                        else
                            self.groupUnitAliveDict[group_name][unitName] = true
                        end
                    end
                end
                Spearhead.DcsUtil.DestroyGroup(group_name)
            end
        end

        Init(o)
        return o;
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.Mission = Mission