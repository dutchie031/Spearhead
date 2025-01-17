
local Stage = {}
do --init STAGE DIRECTOR


    local stageDrawingId = 0

    --- @class Stageb
    --- @field zoneName string
    --- @field stageName string
    --- @field stageNumber number
    --- @field isActive boolean
    --- @field isComplete boolean
    --- @field AddStageCompleteListener fun(self:Stage, listener:StageCompleteListener)
    --- @field IsComplete fun(self:Stage) : boolean
    --- @field PreActivate fun(self:Stage)
    --- @field ActivateStage fun(self:Stage)
    --- @field ActivateBlueStage fun(self:Stage)
    --- @field MarkStage fun(self:Stage, blue:boolean?)
    --- @field ActivateMissionsIfApplicable fun(self:Stage)
    --- @field GetStatusMessage fun(self:Stage) : string|nil
    --- @field _database Database
    --- @field _db StageData
    --- @field _logger Logger
    --- @field _preActivated boolean
    --- @field _activeStage integer
    --- @field _stageConfig StageConfig
    --- @field _stageDrawingId integer
    --- @field _spawnedGroups Array<string>
    --- @field _stageCompleteListeners Array<StageCompleteListener>

    --- @class StageData
    --- @field missionsByCode table<string, Mission>
    --- @field missions Array<Mission>
    --- @field sams Array<Mission>
    --- @field blueSams Array<BlueSam>
    --- @field airbases Array<StageBase>

    ---@class StageCompleteListener 
    ---@field onStageCompleted fun(self:StageCompleteListener, stage:Stage)
    
    ---comment
    ---@param stageZone_name string
    ---@param stageNumber number
    ---@param database table
    ---@param logger table
    ---@param stageConfig StageConfig
    ---@return Stage?
    function Stage:new(stageZone_name, stageNumber, stageName, database, logger, stageConfig)
        local o = {}
        setmetatable(o, { __index = self })

        ---@param self Stage
        ---@param stageZoneName string
        ---@param stageNumber number
        ---@param database table
        ---@param logger table
        ---@param stageConfig StageConfig
        local Construct = function(self, stageZoneName, stageName, stageNumber, database, logger, stageConfig)

            self.zoneName = stageZoneName
            self.stageNumber = stageNumber
            self.isActive = false
            self.isComplete = false
            self.stageName = stageName

            self._database = database
            self._logger = logger
            self._db = {
                missionsByCode = {},
                missions = {},
                sams ={},
                blueSams = {},
                airbases ={}
            }
            self._preActivated = false
            self._stageConfig = stageConfig or {}
            self._stageDrawingId = stageDrawingId + 1
            self._spawnedGroups = {}
            self._stageCompleteListeners = {}

            stageDrawingId = stageDrawingId + 1

            self._logger:info("Initiating new Stage with name: " .. self.zoneName)

            local missionZones = database:getMissionsForStage(self.zoneName)
            for _, missionZone in pairs(missionZones) do
                local mission = Spearhead.internal.Mission:new(missionZone, "primary", database, logger)
                if mission then
                    self._db.missionsByCode[mission.code] = mission
                    if mission.missionType == "SAM" then
                        table.insert(self._db.sams, mission)
                    else
                        table.insert(self._db.missions, mission)
                    end
                end
            end

            local randomMissionNames = database:getRandomMissionsForStage(stageZoneName)

            local randomMissionByName = {}
            for _, missionZoneName in pairs(randomMissionNames) do
                local mission = Spearhead.internal.Mission:new(missionZoneName, "primary", database, logger)
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
                    self._db.missionsByCode[mission.code] = mission
                    if mission.missionType == "SAM" then
                        table.insert(self._db.sams, mission)
                    else
                        table.insert(self._db.missions, mission)
                    end
                end
            end

            for _, mission in pairs(self._db.missionsByCode) do
                mission:AddMissionCompleteListener(o)
            end

            local airbaseIds = database:getAirbaseIdsInStage(self.zoneName)
            if airbaseIds ~= nil and type(airbaseIds) == "table" then
                for _, airbaseId in pairs(airbaseIds) do
                    local airbase = Spearhead.internal.StageBase:New(database, logger, airbaseId)
                    table.insert(self._db.airbases, airbase)
                end
            end

            for _, samZoneName in pairs(database:getBlueSamsInStage(self.zoneName)) do
                local blueSam = Spearhead.classes.stageClasses.BlueSam:new(database, logger, samZoneName)
                table.insert(self._db.blueSams, blueSam)
            end

            local miscGroups = database:getMiscGroupsAtStage(self.zoneName)
            for _, groupName in pairs(miscGroups) do
                Spearhead.DcsUtil.DestroyGroup(groupName)
            end
        end
        Construct(o, stageZone_name,stageName, stageNumber, database, logger, stageConfig)

        ---comment
        ---@param self Stage
        ---@param StageCompleteListener StageCompleteListener an Object with function onStageCompleted(stage)
        o.AddStageCompleteListener = function(self, StageCompleteListener)

            if type(StageCompleteListener) ~= "table" then
                return
            end
            table.insert(self._stageCompleteListeners, StageCompleteListener)
        end

        ---comment
        ---@param self Stage
        local triggerStageCompleteListeners = function(self)
            self.isActive = false
            for _, callable in pairs(self._stageCompleteListeners) do
                local succ, err = pcall( function() 
                    callable:onStageCompleted(self)
                end)
                if err then
                    self._logger:warn("Error in misstion complete listener:" .. err)
                end
            end
        end

        ---comment
        ---@param self Stage
        ---@return boolean
        o.IsComplete = function(self)
            for i, mission in pairs(self._db.missions) do
                local state = mission:GetState()
                if state == "ACTIVE" or state == "NEW" then
                    return false
                end
            end
            return true
        end

        ---comment
        ---@param self Stage
        ---@param time any
        ---@return nil
        local CheckContinuousAsync = function(self, time)
            self._logger:info("Checking stage completion for stage: " .. self.zoneName)
            if self._activeStage == self.stageNumber then
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
        ---@param self Stage
        o.PreActivate = function(self)
            if self._preActivated == false then
                self._preActivated = true
                for key, mission in pairs(self._db.sams) do
                    if mission and mission.Activate then
                        mission:Activate()
                    end
                end

                for _, airbase in pairs(self._db.airbases) do
                    airbase:ActivateRedStage()
                end
            end
        end

        ---comment
        ---@param self Stage
        local activateMissionsIfApplicableAsync = function(self)
            self:ActivateMissionsIfApplicable()
        end

        ---comment
        ---@param self Stage
        ---@param blue boolean?
        o.MarkStage = function(self, blue)
            if blue == nil then blue = false end

            local fillColor = {1, 0, 0, 0.1}
            local line ={ 1, 0,0, 1 }
            if blue == true then
                fillColor = {0, 0, 1, 0.1}
                line ={ 0, 0,1, 1 }
            end

            local zone = Spearhead.DcsUtil.getZoneByName(self.zoneName)
            if zone and self._stageConfig.isDrawStagesEnabled == true then
                self._logger:debug("drawing stage")
                if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                    trigger.action.circleToAll(-1, self._stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, {0,0,0,0}, {0,0,0,0},4, true)
                else
                    --trigger.action.circleToAll(-1, self.stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, { 1, 0,0, 1 }, {1,0,0,1},4, true)
                    trigger.action.quadToAll( -1, self._stageDrawingId,  zone.verts[1], zone.verts[2], zone.verts[3],  zone.verts[4], {0,0,0,0}, {0,0,0,0}, 4, true)
                end

                trigger.action.setMarkupColorFill(self._stageDrawingId, fillColor)
                trigger.action.setMarkupColor(self._stageDrawingId, line)
            end
        end
        
        ---comment
        ---@param self Stage
        o.ActivateStage = function(self)
            self.isActive = true;

            pcall(function()
                self:MarkStage()
            end)

            self:PreActivate()
            
            local miscGroups = self._database:getMiscGroupsAtStage(self.zoneName)
            self._logger:debug("Activating Misc groups for zone: " .. Spearhead.Util.tableLength(miscGroups))
            for _, groupName in pairs(miscGroups) do
                if self._spawnedGroups[groupName] ~= true then
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    self._spawnedGroups[groupName] = true
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
                            else
                                Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                            end
                        end
                    end
                end
            end

            for _, mission in pairs(self._db.missions) do
                if mission.missionType == Spearhead.internal.Mission.MissionType.DEAD then
                    mission:Activate()
                end
            end
            timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 5)

            timer.scheduleFunction(CheckContinuousAsync, self, timer.getTime() + 60)
        end

        ---comment
        ---@param self Stage
        o.ActivateMissionsIfApplicable = function (self)
            local activeCount = 0

            local availableMissions = {}
            for _, mission in pairs(self._db.missionsByCode) do
                local state = mission:GetState()

                if state == Spearhead.internal.Mission.MissionState.ACTIVE then
                    activeCount = activeCount + 1
                end

                if state == Spearhead.internal.Mission.MissionState.NEW then
                    table.insert(availableMissions, mission)
                end
            end

            local max = self._stageConfig.maxMissionsPerStage or 10

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
                            activeCount = activeCount + 1;
                        end
                        availableMissionsCount = availableMissionsCount - 1
                    end
                end
            end

        end

        ---comment
        ---@param self Stage
        local ActivateBlueAsync = function(self)
            pcall(function()
                self:MarkStage(true)
            end)

            for _, blueSam in pairs(self._db.blueSams) do
                blueSam:Activate()
            end

            for _, airbase in pairs(self._db.airbases) do
                airbase:ActivateBlueStage()
            end

            return nil
        end

        o.persistedStateSpawned = false
        ---Sets airfields to blue and spawns friendly farps
        ---@param self Stage
        o.ActivateBlueStage = function(self)
            logger:debug("Setting stage '" .. Spearhead.Util.toString(self.zoneName) .. "' to blue")
            
            for _, mission in pairs(self._db.missions) do
                mission:SpawnsPersistedState()
            end

            for _, mission in pairs(self._db.sams) do
                mission:SpawnsPersistedState()
            end

            local miscGroups = self._database:getMiscGroupsAtStage(self.zoneName)
            for _, groupName in pairs(miscGroups) do
                if self._spawnedGroups[groupName] ~= true then
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    self._spawnedGroups[groupName] = true
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
                            else
                                if unit and unit:isExist() then
                                    Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                                end
                            end
                        end
                    end
                end
            end

            timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)

        end

        ---comment
        ---@param self Stage
        o.GetStatusMessage = function(self)

            if self.isActive == false then return nil end

            local completedMissions = 0
            local totalMissions = 0

            for _, mission in pairs(self._db.missions) do
                totalMissions = totalMissions + 1
                if mission:GetState() == "COMPLETED" then
                    completedMissions = completedMissions + 1
                end
            end

            local string = self.stageName .. ": \n     Missions : " .. completedMissions .. "/" .. totalMissions
            return string
        end

        -- o.OnStatusRequestReceived = function(self, groupId)
        --     if self.activeStage ~= self.stageNumber then
        --         return
        --     end

        --     trigger.action.outTextForGroup(groupId, "Status Update incoming... ", 3)

        --     local text = "Mission Status: \n"

        --     local  totalmissions = 0
        --     local completedMissions = 0
        --     for _, mission in pairs(self.db.missionsByCode) do
        --         totalmissions = totalmissions + 1
        --         if mission.missionState == Spearhead.internal.Mission.MissionState.ACTIVE then

        --             text = text .. "\n [" .. mission.code .. "] " .. mission.name .. 
        --             " ("  ..  mission.name .. ") \n"
        --         end
               
        --         if mission.missionState == Spearhead.internal.Mission.MissionState.COMPLETED then
        --             completedMissions = completedMissions + 1
        --         end
        --     end

        --     local completionPercentage = math.floor((completedMissions / totalmissions) * 100)
        --     text = text .. " \n Missions Complete: " .. completionPercentage .. "%" 

        --     self.logger:debug(text)
        --     trigger.action.outTextForGroup(groupId, text, 20)
        -- end

        ---comment
        ---@param self Stage
        ---@param number integer
        o.OnStageNumberChanged = function (self, number)

            if self._activeStage == number then --only activate once for a stage
                return
            end

            local previousActive = self._activeStage
            self._activeStage = number
            if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
                self:PreActivate()
            end

            if number == self.stageNumber then
                self:ActivateStage()
            end

            if previousActive <= self.stageNumber then
                if number > self.stageNumber then
                    self:ActivateBlueStage()
                end
            end
        end

        ---comment
        ---@param self Stage
        ---@param object table
        o.OnUnitLost = function(self, object)
            local unitName = object:getName()
            local pos = object:getPoint()
            local type = object:getDesc().typeName
            local position = object:getPosition()
            local heading = math.atan2(position.x.z, position.x.x)
            local country_id = object:getCountry()
            Spearhead.classes.persistence.Persistence.UnitKilled(unitName, pos, heading, type, country_id)
        end

        ---comment
        ---@param self Stage
        ---@param mission Mission
        o.OnMissionComplete = function(self, mission)
            if(self:IsComplete()) then
                timer.scheduleFunction(triggerStageCompleteListeners, self, timer.getTime() + 15)
            else
                timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 10)
            end
        end

        Spearhead.Events.AddOnPlayerEnterUnitListener(o)
        Spearhead.Events.AddStageNumberChangedListener(o)
        return o
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.Stage = Stage