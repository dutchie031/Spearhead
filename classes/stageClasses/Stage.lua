
local Stage = {}
do --init STAGE DIRECTOR


    local stageDrawingId = 0

    ---comment
    ---@param stagezone_name string
    ---@param database table
    ---@param logger table
    ---@return table?
    function Stage:new(stagezone_name, database, logger, stageConfig)
        local o = {}
        setmetatable(o, { __index = self })

        o.zoneName = stagezone_name

        local split = Spearhead.Util.split_string(stagezone_name, "_")
        if Spearhead.Util.tableLength(split) < 2 then
            Spearhead.AddMissionEditorWarning("Stage zone with name " .. stagezone_name .. " does not have a order number or valid format")
            return nil
        end

        local orderNumber = tonumber(split[2])
        if orderNumber == nil then
            Spearhead.AddMissionEditorWarning("Stage zone with name " .. stagezone_name .. " does not have a valid order number : " .. split[2])
            return nil
        end

        o.stageNumber = orderNumber
        o.isActive = false
        o.isComplete = false
        o.database = database
        o.logger = logger
        o.db = {}
        o.db.missionsByCode = {}
        o.db.missions = {}
        o.db.sams = {}
        o.db.blueSams = {}
        o.db.airbases = {}
        o.activeStage = -99
        o.preActivated = false
        o.stageConfig = stageConfig or {}
        o.stageDrawingId = stageDrawingId + 1
    

        stageDrawingId = stageDrawingId + 1

        do --Init Stage
            logger:info("Initiating new Stage with name: " .. stagezone_name)

            local missionZones = database:getMissionsForStage(stagezone_name)
            for _, missionZone in pairs(missionZones) do
                local mission = Spearhead.internal.Mission:new(missionZone, database, logger)
                if mission then
                    o.db.missionsByCode[mission.code] = mission
                    if mission.missionType == Spearhead.internal.Mission.MissionType.SAM then
                        table.insert(o.db.sams, mission)
                    else
                        table.insert(o.db.missions, mission)
                    end
                end
            end

            local randomMissionNames = database:getRandomMissionsForStage(stagezone_name)

            local randomMissionByName = {}
            for _, missionZoneName in pairs(randomMissionNames) do
                local mission = Spearhead.internal.Mission:new(missionZoneName, database, logger)
                if mission then
                    if randomMissionByName[mission.name] == nil then
                        randomMissionByName[mission.name] = {}
                    end
                    table.insert(randomMissionByName[mission.name], mission)
                end
            end

            for _, missions in pairs(randomMissionByName) do
                local mission = Spearhead.Util.randomFromList(missions)
                if mission then
                    o.db.missionsByCode[mission.code] = mission
                    if mission.missionType == Spearhead.internal.Mission.MissionType.SAM then
                        table.insert(o.db.sams, mission)
                    else
                        table.insert(o.db.missions, mission)
                    end
                end
            end

            local airbaseIds = database:getAirbaseIdsInStage(o.zoneName)
            if airbaseIds ~= nil and type(airbaseIds) == "table" then
                for _, airbaseId in pairs(airbaseIds) do
                    local airbase = Spearhead.internal.StageBase:New(database, logger, airbaseId)
                    table.insert(o.db.airbases, airbase)
                end
            end

            for _, samZoneName in pairs(database:getBlueSamsInStage(o.zoneName)) do
                local blueSam = Spearhead.classes.stageClasses.BlueSam:new(database, logger, samZoneName)
                table.insert(o.db.blueSams, blueSam)
            end

            local miscGroups = database:getMiscGroupsAtStage(o.zoneName)
            for _, groupName in pairs(miscGroups) do
                Spearhead.DcsUtil.DestroyGroup(groupName)
            end
        end

        o.StageCompleteListeners = {}
        ---comment
        ---@param self table
        ---@param StageCompleteListener table an Object with function onStageCompleted(stage)
        o.AddStageCompleteListener = function(self, StageCompleteListener)

            if type(StageCompleteListener) ~= "table" then
                return
            end
            table.insert(self.StageCompleteListeners, StageCompleteListener)
        end

        local triggerStageCompleteListeners = function(self)
            self.isActive = false
            for _, callable in pairs(self.StageCompleteListeners) do
                local succ, err = pcall( function() 
                    callable:onStageCompleted(self)
                end)
                if err then
                    self.logger:warn("Error in misstion complete listener:" .. err)
                end
            end
        end

        o.IsComplete = function(self)
            for i, mission in pairs(self.db.missions) do
                local state = mission:GetState()
                if state == Spearhead.internal.Mission.MissionState.ACTIVE or state == Spearhead.internal.Mission.MissionState.NEW then
                    return false
                end
            end
            return true
        end

        local CheckContinuousAsync = function(self, time)
            self.logger:info("Checking stage completion for stage: " .. self.zoneName)
            if self.activeStage == self.stageNumber then
                return nil -- stop looping if this stage is not even active
            end

            if self:IsComplete() == true then
                self.isComplete = true
                triggerStageCompleteListeners(self)
                return nil
            end
            return time + 60
        end

        ---Activates all SAMS, Airbase units etc all at once.
        ---@param self table
        o.PreActivate = function(self)
            if self.preActivated == false then
                self.preActivated = true
                for key, mission in pairs(self.db.sams) do
                    if mission and mission.Activate then
                        mission:Activate()
                    end
                end
                self.logger:debug("Pre-activating stage with airbase groups amount: " .. Spearhead.Util.tableLength(self.db.redAirbasegroups))

                for _, airbase in pairs(self.db.airbases) do
                    airbase:ActivateRedStage()
                end
            end

            if self.activeStage == self.stageNumber then
                for _, mission in pairs(self.db.sams) do
                    self:AddCommmandsForMissionToAllPlayers(mission)
                end
            end
        end

        local activateMissionsIfApplicableAsync = function(self)
            self:ActivateMissionsIfApplicable(self)
        end

        o.MarkStage = function(self, blue)
            local fillColor = {1, 0, 0, 0.1}
            local line ={ 1, 0,0, 1 }
            if blue == true then
                fillColor = {0, 0, 1, 0.1}
                line ={ 0, 0,1, 1 }
            end

            local zone = Spearhead.DcsUtil.getZoneByName(self.zoneName)
            if zone and self.stageConfig:isDrawStagesEnabled() == true then
                self.logger:debug("drawing stage")
                if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                    trigger.action.circleToAll(-1, self.stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, {0,0,0,0}, {0,0,0,0},4, true)
                else
                    --trigger.action.circleToAll(-1, self.stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, { 1, 0,0, 1 }, {1,0,0,1},4, true)
                    trigger.action.quadToAll( -1, self.stageDrawingId,  zone.verts[1], zone.verts[2], zone.verts[3],  zone.verts[4], {0,0,0,0}, {0,0,0,0}, 4, true)
                end

                trigger.action.setMarkupColorFill(self.stageDrawingId, fillColor)
                trigger.action.setMarkupColor(self.stageDrawingId, line)
            end
        end
        
        o.ActivateStage = function(self)
            self.isActive = true;

            pcall(function()
                self:MarkStage()
            end)

            self:PreActivate()
            
            local miscGroups = self.database:getMiscGroupsAtStage(self.zoneName)
            self.logger:debug("Activating Misc groups for zone: " .. Spearhead.Util.tableLength(miscGroups))
            for _, groupName in pairs(miscGroups) do
                local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                if group then
                    for _, unit in pairs(group:getUnits()) do
                        local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                            if deathState.isCleaned == false then
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
                            end
                        else
                            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                        end
                    end
                end
            end

            for _, mission in pairs(self.db.missions) do
                if mission.missionType == Spearhead.internal.Mission.MissionType.DEAD then
                    mission:Activate()
                    self:AddCommmandsForMissionToAllPlayers(mission)
                end
            end
            timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 5)

            timer.scheduleFunction(CheckContinuousAsync, self, timer.getTime() + 60)
        end

        o.ActivateMissionsIfApplicable = function (self)
            local activeCount = 0

            local availableMissions = {}
            for _, mission in pairs(self.db.missionsByCode) do
                local state = mission:GetState()

                if state == Spearhead.internal.Mission.MissionState.ACTIVE then
                    activeCount = activeCount + 1
                end

                if state == Spearhead.internal.Mission.MissionState.NEW then
                    table.insert(availableMissions, mission)
                end
            end

            local max = self.stageConfig:getMaxMissionsPerStage() or 10

            local availableMissionsCount = Spearhead.Util.tableLength(availableMissions)
            if activeCount < max and availableMissionsCount > 0  then
                for i = activeCount+1, max do
                    if availableMissionsCount == 0 then
                        i = max+1 --exits this loop
                    else
                        local index = math.random(1, availableMissionsCount)
                        local mission = table.remove(availableMissions, index)
                        if mission then
                            mission:Activate()
                            self:AddCommmandsForMissionToAllPlayers(mission)
                            activeCount = activeCount + 1;
                        end
                        availableMissionsCount = availableMissionsCount - 1
                    end
                end
            end

        end

        ---Cleans up all missions
        ---@param self table
        o.Clean = function(self)
            for key, mission in pairs(self.db.missions) do
                mission:Cleanup()
            end

            for key, samMission in pairs(self.db.sams) do
                samMission:Cleanup()
            end

            for _, airbase in pairs(self.db.airbases) do
                for _, redGroupName in pairs(airbase.redAirbaseGroupNames) do
                    Spearhead.DcsUtil.DcsUtil.DestroyGroup(redGroupName)
                end
            end

            logger:debug("'" .. Spearhead.Util.toString(self.zoneName) .. "' cleaned")
        end

        local ActivateBlueAsync = function(self)
            pcall(function()
                self:MarkStage(true)
            end)

            for _, blueSam in pairs(self.db.blueSams) do
                blueSam:Activate()
            end

            for _, airbase in pairs(self.db.airbases) do
                airbase:ActivateBlueStage()
            end

            return nil
        end

        o.persistedStateSpawned = false
        ---Sets airfields to blue and spawns friendly farps
        o.ActivateBlueStage = function(self)
            logger:debug("Setting stage '" .. Spearhead.Util.toString(self.zoneName) .. "' to blue")
            
            for _, mission in pairs(self.db.missions) do
                mission:SpawnsPersistedState()
            end

            for _, mission in pairs(self.db.sams) do
                mission:SpawnsPersistedState()
            end

            local miscGroups = self.database:getMiscGroupsAtStage(self.zoneName)
            for _, groupName in pairs(miscGroups) do
                local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                if group then
                    for _, unit in pairs(group:getUnits()) do
                        local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                            if deathState.isCleaned == false then
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
                            end
                        else
                            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                        end
                    end
                end
            end

            timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)

        end

        o.OnStatusRequestReceived = function(self, groupId)
            if self.activeStage ~= self.stageNumber then
                return
            end

            trigger.action.outTextForGroup(groupId, "Status Update incoming... ", 3)

            local text = "Mission Status: \n"

            local  totalmissions = 0
            local completedMissions = 0
            for _, mission in pairs(self.db.missionsByCode) do
                totalmissions = totalmissions + 1
                if mission.missionState == Spearhead.internal.Mission.MissionState.ACTIVE then

                    text = text .. "\n [" .. mission.code .. "] " .. mission.name .. 
                    " ("  ..  mission.missionTypeDisplayName .. ") \n"
                end
               
                if mission.missionState == Spearhead.internal.Mission.MissionState.COMPLETED then
                    completedMissions = completedMissions + 1
                end
            end

            local completionPercentage = math.floor((completedMissions / totalmissions) * 100)
            text = text .. " \n Missions Complete: " .. completionPercentage .. "%" 

            self.logger:debug(text)
            trigger.action.outTextForGroup(groupId, text, 20)
        end

        o.OnStageNumberChanged = function (self, number)

            if self.activeStage == number then --only activate once for a stage
                return
            end

            local previousActive = self.activeStage
            self.activeStage = number
            if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
                self:PreActivate()
            end

            if number == self.stageNumber then
                self:ActivateStage()
            end

            if previousActive <= self.stageNumber then
                if number > self.stageNumber then
                    self:ActivateBlueStage()
                    self:RemoveAllMissionCommands()
                end
            end
        end

        --- input = { self, groupId, missionCode }
        local ShowBriefingClicked = function (input)
            
            local self = input.self
            local groupId = input.groupId
            local missionCode = input.missionCode

            local mission  = self.db.missionsByCode[missionCode]
            if mission then
                mission:ShowBriefing(groupId)
            end
        end
        
        o.RemoveMissionCommands = function (self, mission)

            self.logger:debug("Removing commands for: " .. mission.name)

            local folderName = mission.name .. "(" .. mission.missionTypeDisplayName .. ")"
            for i = 0, 2 do
                local players = coalition.getPlayers(i)
                for _, playerUnit in pairs(players) do
                    local groupId = playerUnit:getGroup():getID()
                    missionCommands.removeItemForGroup(groupId, { "Missions", folderName })
                end
            end
        end

        o.OnUnitLost = function(self, object)
            local unitName = object:getName()
            local pos = object:getPoint()
            local type = object:getDesc().typeName
            local position = object:getPosition()
            local heading = math.atan2(position.x.z, position.x.x)
            local country_id = object:getCountry()
            Spearhead.classes.persistence.Persistence.UnitKilled(unitName, pos, heading, type, country_id)
        end

        o.RemoveAllMissionCommands = function (self)
            for _, mission in pairs(self.db.missionsByCode) do
                self:RemoveMissionCommands(mission)
            end
        end

        o.AddCommandsForMissionToGroup = function (self, groupId, mission)
            local folderName = mission.name .. "(" .. mission.missionTypeDisplayName .. ")"
            missionCommands.addSubMenuForGroup(groupId, folderName, { "Missions"} )
            missionCommands.addCommandForGroup(groupId, "Show Briefing", { "Missions", folderName }, ShowBriefingClicked, { self = self, groupId = groupId, missionCode = mission.code })
        end

        o.AddCommmandsForMissionToAllPlayers = function(self, mission)
            for i = 0, 2 do
                local players = coalition.getPlayers(i)
                for _, playerUnit in pairs(players) do
                    local groupId = playerUnit:getGroup():getID()
                    self:AddCommandsForMissionToGroup(groupId, mission)
                end
            end
        end
        
        o.OnPlayerEntersUnit = function (self, unit)
            if self.activeStage == self.stageNumber then
                local groupId = unit:getGroup():getID()
                for _, mission in pairs(self.db.missionsByCode) do
                    if mission.missionState == Spearhead.internal.Mission.MissionState.ACTIVE then
                        self:AddCommandsForMissionToGroup(groupId, mission)
                    end
                end
            end
        end

        local removeMissionCommandsDelayed = function(input)
            local self = input.self
            local mission = input.mission
            self:RemoveMissionCommands(mission)
        end
        
        o.OnMissionComplete = function(self, mission)
            timer.scheduleFunction(removeMissionCommandsDelayed, { self = self, mission = mission}, timer.getTime() + 20)

            if(self:IsComplete()) then
                timer.scheduleFunction(triggerStageCompleteListeners, self, timer.getTime() + 15)
            else
                timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 10)
            end
        end

        for _, mission in pairs(o.db.missionsByCode) do
            mission:AddMissionCompleteListener(o)
        end

        Spearhead.Events.AddOnPlayerEnterUnitListener(o)
        Spearhead.Events.AddOnStatusRequestReceivedListener(o)
        Spearhead.Events.AddStageNumberChangedListener(o)
        return o
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.Stage = Stage