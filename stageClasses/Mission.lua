
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
            local category = object:getCategory()
            if category == Object.Category.UNIT then
                local unitName = object:getName()
                local groupName = object:getGroup():getName()
                self.groupUnitAliveDict[groupName][unitName] = false

                if self.targetAliveStates[groupName][unitName] then
                    self.targetAliveStates[groupName][unitName] = false
                end
            elseif category == Object.Category.STATIC  then
                local name = object:getName()
                self.groupUnitAliveDict[name][name] = false

                if self.targetAliveStates[name][name] then
                    self.targetAliveStates[name][name] = false
                end
            end
            CheckStateAsync(false)
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
            --[[
                TODO: Check own state based on mission type 
            ]]--

            local specificTargetsAlive = false
            if self.hasSpecificTargets == true then
                for groupName, unitNameDict in pairs(self.targetAliveStates) do
                    for unitName, isAlive in pairs(unitNameDict) do
                        if isAlive == true then
                            specificTargetsAlive = true
                        end
                    end
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
                            aliveGroups = 1
                        end
                    end
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
                TriggerMissionComplete(self)
                --Schedule cleanup after 5 minutes of mission complete
                timer.scheduleFunction(CleanupDelayedAsync, self, timer.getTime() + 300)
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

        o.ShowBriefing = function(self, groupId)
            local text = "Mission [" .. self.code .. "] ".. self.name .. "\n \n" .. self.missionbriefing .. " \n \nState TODO"
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
                    self.startingUnits = self.startingUnits + 1
                    Spearhead.Events.addOnUnitLostEventListener(group_name, self)

                    self.groupUnitAliveDict[group_name][group_name] = true
                    if Spearhead.Util.startswith(group_name, "TGT_") == true then
                        self.targetAliveStates[group_name][group_name] = true
                    end

                else
                    local group = Group.getByName(group_name)
                    local isGroupTarget = Spearhead.Util.startswith(group_name, "TGT_")

                    self.startingUnits = self.startingUnits + group:getInitialSize()
                    for _, unit in pairs(group:getUnits()) do
                        local unitName = unit:getName()
                        Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                        self.groupUnitAliveDict[group_name][unitName] = true

                        if isGroupTarget == true or Spearhead.Util.startswith(unitName, "TGT_") == true then
                            self.targetAliveStates[group_name][unitName] = true
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

Spearhead.internal.Mission = Mission