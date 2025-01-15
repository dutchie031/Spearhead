



local ExtraStage = {}
do
    local stageDrawingId = 400

    function ExtraStage:new(database, logger, stageConfig, stageZoneName, stageIndex)

        local o = {}
        setmetatable(o, {__index = self} )


        o.database = database
        o.logger = logger
        o.zoneName = stageZoneName
        o.stageNumber = tonumber(stageIndex)
        o.stageConfig = stageConfig

        o.isActivated = false
        o.isComplete = false
        o.isAllMissionsComplete = false

        o.stageDrawingId = stageDrawingId + 1
        stageDrawingId = stageDrawingId + 1

        o.missions = {}
        o.miscGroups = {}
        o.airBases = {}
        o.miscGroups = {}

        o.spawnedGroups = {}

        do -- init
            do -- missions
                local missions = database:getMissionsForStage(stageZoneName)
                for _, missionZone in pairs(missions) do
                    local mission = Spearhead.internal.Mission:new(missionZone, "secondary", database, logger)
                    if mission then
                        o.missions[mission.code] = mission
                    end
                end
            end

            do -- random missions
                local randomMissionNames = database:getRandomMissionsForStage(stageZoneName)

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
                        o.missions[mission.code] = mission
                    end
                end

                local miscGroups = database:getMiscGroupsAtStage(o.zoneName)
                for _, groupName in pairs(miscGroups) do
                    table.insert(o.miscGroups, groupName)
                    Spearhead.DcsUtil.DestroyGroup(groupName)
                end
            end
        end

        o.MarkStage = function(self, neutral)
            local fillColor = {1, 0, 0, 0.1}
            local line ={ 1, 0,0, 1 }
            if neutral == true then
                fillColor = { 85/255, 85/255, 85/255, 0.1}
                line ={ 85/255, 85/255, 85/255, 1}
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

        o.IsComplete = function(self)
            for i, mission in pairs(self.missions) do
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
                pcall(function()
                    self:MarkStage(true)
                end)
                return nil
            end
            return time + 60
        end


        local activateStage = function(self)
            if self.isActivated == true then return end
            
            pcall(function()
                self:MarkStage()
            end)

            for _, mission in pairs(self.missions) do
                mission:Activate()
            end

            for _, groupName in ipairs(self.miscGroups) do
                if self.spawnedGroups[groupName] ~= true then
                    local object, isStatic = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    self.spawnedGroups[groupName] = true
                    if object then
                        if isStatic == true then
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(object:getName())
                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, object:getName(), deathState.type, deathState.pos, deathState.heading)
                            else
                                Spearhead.Events.addOnUnitLostEventListener(groupName, self)
                            end
                        elseif isStatic == false then
                            for _, unit in pairs(object:getUnits()) do 
                                local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())
                                if deathState and deathState.isDead == true then
                                    Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
                                else
                                    Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                                end
                            end
                        end
                    end
                end
            end

            timer.scheduleFunction(CheckContinuousAsync, self, timer.getTime() + 60)
        end

        o.OnStageNumberChanged = function (self, number)
            local parsed = tonumber(number)
            if parsed and parsed >= self.stageNumber then
               timer.scheduleFunction(activateStage, self, timer.getTime() + 4)
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

        o.AddCommandsForMissionToGroup = function (self, groupId, mission)
            local folderName = mission.name .. "(" .. mission.missionTypeDisplayName .. ")"
            missionCommands.addSubMenuForGroup(groupId, folderName, { "Secondary Missions"} )
            missionCommands.addCommandForGroup(groupId, "Show Briefing", { "Secondary Missions", folderName }, ShowBriefingClicked, { self = self, groupId = groupId, missionCode = mission.code })
        end

        o.RemoveMissionCommands = function (self, mission)

            self.logger:debug("Removing commands for: " .. mission.name)

            local folderName = mission.name .. "(" .. mission.missionTypeDisplayName .. ")"
            for i = 0, 2 do
                local players = coalition.getPlayers(i)
                for _, playerUnit in pairs(players) do
                    local groupId = playerUnit:getGroup():getID()
                    missionCommands.removeItemForGroup(groupId, { "Secondary Missions", folderName })
                end
            end
        end

        
        local removeMissionCommandsDelayed = function(input)
            local self = input.self
            local mission = input.mission
            self:RemoveMissionCommands(mission)
        end

        local activateMissionsIfApplicableAsync = function(self)
            self:ActivateMissionsIfApplicable(self)
        end

        o.OnMissionComplete = function(self, mission)
            timer.scheduleFunction(removeMissionCommandsDelayed, { self = self, mission = mission}, timer.getTime() + 20)

            if(self:IsComplete()) then
                pcall(function()
                    self:MarkStage(true)
                end)
                return
            else
                timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 10)
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

        Spearhead.Events.AddStageNumberChangedListener(o)

        return o
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end

Spearhead.classes.stageClasses.ExtraStage = ExtraStage