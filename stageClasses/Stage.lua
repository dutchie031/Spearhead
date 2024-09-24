
local Stage = {}
do --init STAGE DIRECTOR

    ---comment
    ---@param stagezone_name string
    ---@param database table
    ---@param logger table
    ---@return table?
    function Stage:new(stagezone_name, database, logger)
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
        o.database = database
        o.logger = logger
        o.db = {}
        o.db.missions = {}
        o.db.sams = {}
        o.db.redAirbasegroups = {}
        o.db.blueAirbasegroups = {}
        o.db.airbaseIds = {}
        o.db.farps = {}
        o.activeStage = 0
        o.preActivated = false

        do --Init Stage
            logger:info("Initiating new Stage with name: " .. stagezone_name)

            local missionZones = database:getMissionsForStage(stagezone_name)
            for _, missionZone in pairs(missionZones) do
                local mission = Spearhead.internal.Mission:new(missionZone, database)
                if mission then
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
                local mission = Spearhead.internal.Mission:new(missionZoneName, database)
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
                    if mission.missionType == Spearhead.internal.Mission.MissionType.SAM then
                        table.insert(o.db.sams, mission)
                    else
                        table.insert(o.db.missions, mission)
                    end
                end
            end

            local airbaseIds = database:getAirbaseIdsInStage(o.zoneName)
            if airbaseIds ~= nil and type(airbaseIds) == "table" then
                o.db.airbaseIds = airbaseIds
                for _, airbaseId in pairs(airbaseIds) do
                    
                    for _, groupName in pairs(database:getRedGroupsAtAirbase(airbaseId)) do 
                        table.insert(o.db.redAirbasegroups, groupName)
                    end

                    for _, groupName in pairs(database:getBlueGroupsAtAirbase(airbaseId)) do 
                        table.insert(o.db.blueAirbasegroups, groupName)
                    end
                end
            end

            local farps = database:getFarpZonesInStage(o.zoneName)
            if farps ~= nil and type(farps) == "table" then o.db.farps = farps end
        end

        o.IsComplete = function(self)
            for i, mission in pairs(self.db.missions) do
                local state = mission:GetState()
                if state == Spearhead.Mission.MissionState.ACTIVE or state == Spearhead.Mission.MissionState.NEW then
                    return false
                end
            end
            return true
        end

        ---Activates all SAMS, Airbase units etc all at once.
        ---@param self table
        o.PreActivate = function(self)
            if self.preActivated == true then return end
            self.preActivated = true
            for key, mission in pairs(self.db.sams) do
                if mission and mission.Activate then
                    mission:Activate()
                end
            end

            self.logger:debug("Pre-activating stage with airbase groups amount: " .. Spearhead.Util.tableLength(self.db.redAirbasegroups))

            for _ , groupName in pairs(self.db.redAirbasegroups) do
                Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
            end
        end

        o.ActiveStage = function(self)
            if self.preActivated == false then
                self:PreActivate()
            end
            
            local miscGroups = self.database:getMiscGroupsAtStage(self.zoneName)
            self.logger:debug("Activating Misc groups for zone: " .. Spearhead.Util.tableLength(miscGroups))
            for _, groupName in pairs(miscGroups) do
                Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
            end

            for _, mission in pairs(self.db.missions) do
                if mission.missionType == Spearhead.internal.Mission.MissionType.DEAD then
                    mission:Activate()
                end
            end

            --[[
                TODO: Activate Stage
            ]]--

        end

        o.ActivateAllMissions = function(self)
            for _, mission in pairs(self.db.missions) do
                mission:Activate()
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
            for key, airbaseId in pairs(self.db.airbaseIds) do
                local airbase = Spearhead.DcsUtil.getAirbaseById(airbaseId)

                if airbase then
                    local startingCoalition = Spearhead.DcsUtil.getStartingCoalition(airbaseId)
                    if startingCoalition == coalition.side.BLUE then
                        airbase:setCoalition(2)
                        for _, blueGroupName in pairs(self.db.blueAirbasegroups) do
                            Spearhead.DcsUtil.SpawnGroupTemplate(blueGroupName)
                        end
                    else
                        airbase:setCoalition(0)
                    end
                end
            end
        end

        ---Sets airfields to blue and spawns friendly farps
        o.ActivateBlueStage = function(self)
            logger:debug("Setting stage '" .. Spearhead.Util.toString(self.zoneName) .. "' to blue")
            
            for _, groupName in pairs(self.db.redAirbasegroups) do
                Spearhead.DcsUtil.DestroyGroup(groupName)
            end

            for _, mission in pairs(self.db.missions) do
                mission:Cleanup()
            end

            for _, mission in pairs(self.db.sams) do
                mission:Cleanup()
            end

            timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)

            -- for key, farp in pairs(self.db.farps) do
            --     if farp.helipadnames then
            --         for _, helipadName in pairs(farp.helipadnames) do
            --             local helipad = Airbase.getByName(helipadName)
            --             if helipad then
            --                 logger:debug("Enabling: '" .. helipad:getName() .. "'")
            --                 helipad:setCoalition(2)
            --             else
            --                 logger:warn(helipadName .. " not found when spawning farps")
            --             end
            --         end
            --     end

            --     if farp.group_names then
            --         for _, groupName in pairs(farp.group_names) do
            --             Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
            --         end
            --     end
            -- end
        end

        o.OnStatusRequestReceived = function(self, groupId)
            if self.activeStage ~= self.stageNumber then
                return
            end

            trigger.action.outTextForGroup(groupId, "Status Update incoming... ", 3)
            trigger.action.outTextForGroup(groupId, " " .. self.zoneName, 3)
        end

        o.OnStageNumberChanged = function (self, number)

            if self.activeStage == number then --only activate once for a stage
                return
            end

            self.activeStage = number

            if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
                self:PreActivate()
            end

            if number == self.stageNumber then
                self:ActiveStage()
            end

            if number > self.stageNumber then
                self:ActivateBlueStage()
            end
        end

        Spearhead.Events.AddOnStatusRequestReceivedListener(o)
        Spearhead.Events.AddStageNumberChangedListener(o)
        return o
    end
end

Spearhead.internal.Stage = Stage