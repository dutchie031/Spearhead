
--- A mission Object.
local Mission = {}
do -- INIT Mission Class

    local MINIMAL_UNITS_ALIVE_RATIO = 0.20

    local Defaults = {}
    Defaults.MainMenu = "Missions"
    Defaults.SelectMenuSubMenus = { Defaults.MainMenu, "Select Mission" }
    Defaults.ShowMissionSubs = { Defaults.MainMenu }

    local PlayersInMission = {}
    local MissionType = {
        UNKNOWN = 0,
        STRIKE = 1,
        BAI = 2,
        DEAD = 3,
        SAM = 4,
    }

    do --INIT MISSION TYPE FUNCTIONS
        ---Parse string to mission type
        ---@param input string
        MissionType.Parse = function(input)
            if input == nil then
                return Mission.MissionType.UNKNOWN
            end

            input = string.lower(input)
            if input == "dead" then return MissionType.DEAD end
            if input == "strike" then return MissionType.STRIKE end
            if input == "bai" then return MissionType.BAI end
            if input == "sam" then return MissionType.SAM end
            return Mission.MissionType.UNKNOWN
        end

        ---comment
        ---@param input number missionType
        ---@return string text
        MissionType.toString = function(input)
            if input == MissionType.DEAD then return "DEAD" end
            if input == MissionType.STRIKE then return "STRIKE" end
            if input == MissionType.BAI then return "BAI" end
            if input == MissionType.SAM then return "SAM" end
            return "?"
        end
    end
    Mission.MissionType = MissionType

    Mission.MissionState = {
        NEW = 0,
        ACTIVE = 1,
        COMPLETED = 2,
    }

    ---comment
    ---@param missionZoneName string missionZoneName
    ---@param database table db dependency injection
    ---@return table?
    function Mission:new(missionZoneName, database, logger)
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
            local parsedType = Mission.MissionType.Parse(type)
    
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

        o.missionZoneName = missionZoneName
        o.database = database
        o.groupNames = database:getGroupsForMissionZone(missionZoneName)
        o.name = parsed.missionName
        o.missionType = parsed.type
        o.missionTypeDisplayName = Mission.MissionType.toString(o.missionType)
        o.startingGroups = Spearhead.Util.tableLength(o.groupNames)
        o.missionState = Mission.MissionState.NEW
        o.missionbriefing = database:GetDescriptionForMission(missionZoneName)
        o.startingUnits = 0
        o.logger = logger
        o.code = database:GetNewMissionCode()

        o.groupNamesPerUnit = {}

        o.groupUnitAliveDict = {}
        o.targetAliveStates = {}
        o.hasSpecificTargets = false

        local CheckStateAsync = function (self, time)
            self:CheckAndUpdateSelf()
            return nil
        end

        o.OnUnitLost = function(self, object)
            --[[
                OnUnit lost event
            ]]--
            self.logger:debug("Getting on unit lost event")

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
            timer.scheduleFunction(CheckStateAsync, self, timer.getTime() + 3)
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
                    return time + 60
                end
            end

            timer.scheduleFunction(CheckAndUpdate, self, timer.getTime() + 300)
        end

        local CleanupDelayedAsync = function (self, time)
            self:Cleanup()
            return nil
        end

        ---comment
        ---@param self table
        ---@param checkUnitHealth boolean?
        o.CheckAndUpdateSelf = function(self, checkUnitHealth)
            if not checkUnitHealth then checkUnitHealth = false end

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
                trigger.action.outText("Mission " .. self.name .. " (" .. self.code .. ") was completed succesfully!", 20)

                TriggerMissionComplete(self)
                --Schedule cleanup after 5 minutes of mission complete
                --timer.scheduleFunction(CleanupDelayedAsync, self, timer.getTime() + 300)
            end
        end

        ---Activates groups for this mission
        ---@param self table
        o.Activate = function(self)
            if self.missionState == Mission.MissionState.ACTIVE then
                return
            end

            self.missionState = Mission.MissionState.ACTIVE
            do --spawn groups
                for key, groupname in pairs(self.groupNames) do
                    Spearhead.DcsUtil.SpawnGroupTemplate(groupname)
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

                    if Spearhead.Util.startswith(group_name, "TGT_") == true then
                        self.targetAliveStates[group_name][group_name] = true
                    end
                else
                    local group = Group.getByName(group_name)
                    local isGroupTarget = Spearhead.Util.startswith(group_name, "TGT_")

                    self.startingUnits = self.startingUnits + group:getInitialSize()
                    for _, unit in pairs(group:getUnits()) do
                        local unitName = unit:getName()

                        self.groupNamesPerUnit[unitName] = group_name

                        Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                        self.groupUnitAliveDict[group_name][unitName] = true

                        if isGroupTarget == true or Spearhead.Util.startswith(unitName, "TGT_") == true then
                            self.targetAliveStates[group_name][unitName] = true
                        end

                        if self.missionType == MissionType.DEAD or self.missionType == MissionType.SAM then
                            local desc = unit:getDesc()
                            local attributes = desc.attributes
                            if attributes["SAM"] == true or attributes["SAM TR"] or attributes["AAA"] then
                                self.targetAliveStates[group_name][unitName] = true
                            end
                        end
                    end
                end
            end

            if Spearhead.Util.tableLength(self.targetAliveStates) > 0 then
                self.hasSpecificTargets = true
            end
        end

        Init(o)
        return o;
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.Mission = Mission