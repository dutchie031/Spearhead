--[[
# 3. Missions

A mission is a completable objective with a state and a continuous check to see if itself is completed. <br/>
The delay between checks is quite big, but it also is checked on unit deaths and other events.

### Placement
The placement of MISSION trigger zones can be anywhere. <br/>
The order of unit detection is `CAP` > `MISSION` > `AIRBASE` > `STAGE` <br/>
This means that if a unit has a name that starts with `"CAP_"` it will not be included in a mission. <br/>
But all other units in a `MISSION` trigger zone will be managed as part of that mission.

Units inside a `MISSION` do not have to stay within the triggerzone. <br/>
They just need to be inside the zone at the start of the mission. <br/>
You can for example let a `BAI` mission drive back and forth between airbases. The `MISSIONZONE` only needs to be around the units that are part of the objective, not the waypoints.

### Naming
`MISSION_<type>_<name>` <br/>
`RANDOMMISSION_<type>_<name>_<index>` (Read RANDOMISATION below)

With: <br/>
`name` = A name that is easy to remember and type. Like a codename. Exmaples: BYRON, PLUKE, etc. <br/>
`type` = any of the below described types. Special types are marked with an *

TIP: You can click on the type to get more details

<details> 
<summary>SAM*</summary>
&emsp; SAM Sites are managed a little different. SAM Sites can be used to guide players and to protect airfields. <br/>
&emsp; In the future when deepstrike missions might come into scope these SAM sites will also be more important. <br/>
&emsp; SAM sites will be activated when a zone is "Pre-Active". <br/>
&emsp; A stage is "Pre-Active" when there is a CAP base active, or there is other things to do that would need the SAM site to be live (OCA, DEEPSTRIKE, EXTRACTION \<= all feature development)<br/>
&emsp; If you want a SAM site to become active ONLY when the stage is fully active, then `DEAD` is the type for you!

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 

</details>

<details> 
<summary>DEAD</summary>

&emsp; DEAD missions will be spawned on activation of the stage. <br/>
&emsp; ALL DEAD missions will be activated right at the start of a stage. <br/>
&emsp; This might be against the "randomisation" feel, but it is to make sure mission don't get activated randomly and players get ambushed by a random spawn. <br/>

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 


</details>

<details> 
<summary>BAI</summary>
</details>

<details> 
<summary>STRIKE</summary>
&emsp; STRIKE missions will be activated randomly until all of them are completed. <br/>
&emsp; A strike mission can be placed anywhere, even on airbases

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 

</details>

### Randomisation

You can randomise missions. <br/>
Spearhead will pick up all mission zones that start with `"RANDOMMISSION_"` <br/>
Then it will combine each `RANDOMMISSION` in a zone with the same `<name>` and pick a random one. <br/>
It will always pick 1 and only 1.

This means you have some options for randomisation. <br/>
For example, if you have 1 missionzone with name `RANDOMMISSION_SAM_PLUKE_1` that is filled with an SA-2 and another zone with `RANDOMMISSION_SAM_PLUKE_2` filled with an SA-3 then some runs of the mission it will spawn an SA-3 and sometimes spawn an SA-3. (works for any mission type)

What you can also do is add empty `RANDOMMISSION_` zones next to the filled `RANDOMMISSION_` zone. 
For example. You have a `RANDOMMISSION_DEAD_BYRON_1` filled with an SA-19 driving around and 2 more `RANDOMMISSION_DEAD_BYRON_<2 & 3>` zones then it will have a 33% chance of being spawned.
If a zone is empty it will not be briefed, activated or count towards completion of the `STAGE`

]]

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

        o.ShowBriefing = function(self, unitId)
            local text = "Mission #" .. self.code .. "\n" .. self.missionbriefing .. " \n \nState TODO"
            trigger.action.outTextForUnit(unitId, text, 30);
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