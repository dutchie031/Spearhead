local RedBase = {}

---comment
---@param airbaseId number
---@param database table
---@param logger table
---@param capConfig table
---@param stageConfig table
---@return table
function RedBase:new(airbaseId, database, logger, capConfig, stageConfig, casConfig)
    local o = {}
    setmetatable(o, { __index = self })

    o.airGroupNames              = database:getAirGroupsAtAirbase(airbaseId)
    o.database                   = database
    o.airbaseId                  = airbaseId
    o.logger                     = logger
    o.activeStage                = 0
    o.capConfig                  = capConfig
    o.casConfig                  = casConfig
    o.activeCapStages            = (stageConfig or {}).capActiveStages or 10

    o.lastStatesByName           = {}
    o.allGroupsByName            = {}

    o.PrimaryCapGroups           = {}
    o.BackupCapGroups            = {}
    o.EscortGroups               = {}
    o.AttackGroups               = {}

    o.packages                   = {}

    local CheckReschedulingAsync = function(self, time)
        self:CheckAndScheduleAirbaseGroups()
    end

    o.OnGroupStateUpdated        = function(self, capGroup)
        --[[
            There is no update needed for INTRANSIT, ONSTATION or REARMING as the PREVIOUS state already was checked and nothing changes in the actual overal state.
        ]] --
        if capGroup.state == Spearhead.internal.Air.GroupState.INTRANSIT
            or capGroup.state == Spearhead.internal.Air.GroupState.ONSTATION
            or capGroup.state == Spearhead.internal.Air.GroupState.REARMING
        then
            return
        end
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 1)
    end

    for key, name in pairs(o.airGroupNames) do
        if Spearhead.Util.startswith(string.lower(name), "cap_") then
            local capGroup = Spearhead.internal.CapGroup:new(name, airbaseId, logger, database, capConfig)
            if capGroup then
                o.allGroupsByName[name] = capGroup

                if capGroup.groupType == Spearhead.internal.Air.CapGroupType.PRIMARY then
                    table.insert(o.PrimaryCapGroups, capGroup)
                elseif capGroup.groupType == Spearhead.internal.Air.CapGroupType.SECONDARY then
                    table.insert(o.BackupCapGroups, capGroup)
                else
                    table.insert(o.EscortGroups, capGroup)
                end

                capGroup:AddOnStateUpdatedListener(o)
            end
        end

        if Spearhead.Util.startswith(string.lower(name), "cas_") then
            local casGroup = Spearhead.internal.AttackGroup:new(name, o, logger, database, casConfig)
            if casGroup then
                o.allGroupsByName[name] = casGroup
                table.insert(o.AttackGroups, casGroup)
                casGroup:AddOnStateUpdatedListener(o)
            end
        end
    end
    logger:info("Airbase with Id '" ..
        airbaseId .. "' has a total of " .. Spearhead.Util.tableLength(o.allGroupsByName) .. " flights. ".. 
        Spearhead.Util.tableLength(o.PrimaryCapGroups) + Spearhead.Util.tableLength(o.BackupCapGroups) .. "[CAP] " .. 
        Spearhead.Util.tableLength(o.EscortGroups) .. "[Escort] " ..
        Spearhead.Util.tableLength(o.AttackGroups) .. "[Attack]" )

    o.SpawnIfApplicable = function(self)
        self.logger:debug("Check spawns for airbase " .. self.airbaseId)
        for groupName, airGroup in pairs(self.allGroupsByName) do
            local activeStage = tostring(self.activeStage)
            local targetStage = airGroup:GetTargetZone(activeStage)
            logger:debug("Trying to Spawn " .. groupName .. " with tgt stage: " .. tostring(targetStage or "nil"))
            if targetStage ~= nil and airGroup.state == Spearhead.internal.Air.GroupState.UNSPAWNED then
                airGroup:SpawnOnTheRamp()
            end
        end
    end

    o.CheckAndScheduleAirbaseGroups = function(self)
        if capConfig:useAvailableGroupsAsEscort() == true then
            self:CheckAndScheduleAttackers()
            self:CheckAndScheduleCAP()
        else
            self:CheckAndScheduleCAP()
            self:CheckAndScheduleAttackers()
        end
    end

    o.TryGetEscortUnit = function(self)
        for _, group in pairs(self.EscortGroups) do
            if group.state == Spearhead.internal.Air.GroupState.READYONRAMP then
                return group
            end
        end

        if self.capConfig:useAvailableGroupsAsEscort() == true then
            for _, group in pairs(self.PrimaryCapGroups) do
                if group.state == Spearhead.internal.Air.GroupState.READYONRAMP then
                    return group
                end
            end

            for _, group in pairs(self.BackupCapGroups) do
                if group.state == Spearhead.internal.Air.GroupState.READYONRAMP then
                    return group
                end
            end
        end

        return nil
    end

    ---comment
    ---@param database any
    ---@param targetStageNumber any
    ---@return unknown
    local getCasTargetZone = function(database, targetStageNumber)
        local casZone = database:getCasTargetInZone(targetStageNumber)
        if casZone == nil then
            local zones = database:getStageZonesByStageNumber(targetStageNumber)
            return Spearhead.Util.randomFromList(zones)
        end
        return casZone
    end

    ---comment
    ---@param database any
    ---@param targetStageNumber any
    ---@return unknown
    local getSeadTargetZone = function(database, targetStageNumber)
        local casZone = database:getCasTargetInZone(targetStageNumber)
        if casZone == nil then
            local zones = database:getStageZonesByStageNumber(targetStageNumber)
            return Spearhead.Util.randomFromList(zones)
        end
        return casZone
    end

    o.CheckAndScheduleAttackers = function(self)
        for _, casGroup in pairs(self.AttackGroups) do
            local supposedTargetStage = casGroup:GetTargetZone(self.activeStage)
            if supposedTargetStage and casGroup.state == Spearhead.internal.Air.GroupState.READYONRAMP then

                
                local escortGroup = self:TryGetEscortUnit()
                if escortGroup then
                    if casGroup.type == Spearhead.internal.Air.AttackGroupType.CAS then
                        local casTargetZone = getCasTargetZone(self.database, supposedTargetStage)
                        local package = Spearhead.internal.PackagedGroup:newAttackPackage(casGroup, escortGroup, casTargetZone, Spearhead.internal.Air.AttackGroupType.CAS, self.logger)
                        if package then
                            table.insert(self.packages, package)
                            package:SendOut()
                        end
                    elseif casGroup.type == Spearhead.internal.Air.AttackGroupType.SEAD then
                        local casTargetZone = getCasTargetZone(self.database, supposedTargetStage)
                        local package = Spearhead.internal.PackagedGroup:newAttackPackage(casGroup, escortGroup, casTargetZone, Spearhead.internal.Air.AttackGroupType.SEAD, self.logger)
                        if package then
                            table.insert(self.packages, package)
                            package:SendOut()
                        end
                    end
                elseif self.casConfig:requireEscort() == false then
                    self.logger:debug("No escort unit available")
                    if casGroup.type == Spearhead.internal.Air.AttackGroupType.CAS then
                        casGroup:SendOutForCas(supposedTargetStage)
                    elseif casGroup.type == Spearhead.internal.Air.AttackGroupType.SEAD then
                        casGroup:SendOutForSead(supposedTargetStage)
                    end
                end
            end
        end
    end

    o.CheckAndScheduleCAP = function(self)
        self.logger:debug("Check taskings for airbase " .. self.airbaseId)

        local countPerStage = {}
        local requiredPerStage = {}

        --Count back up groups that are active or reassign to the new zone if that's needed
        for _, backupGroup in pairs(self.BackupCapGroups) do
            if backupGroup.state == Spearhead.internal.Air.GroupState.INTRANSIT or backupGroup.state == Spearhead.internal.Air.GroupState.ONSTATION then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if supposedTargetStage ~= backupGroup.assignedStageNumber then
                        backupGroup:SendToStageForCap(supposedTargetStage)
                    end

                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                else
                    backupGroup:SendRTBAndDespawn()
                end
            elseif backupGroup.state == Spearhead.internal.Air.GroupState.RTBINTEN and backupGroup:GetTargetZone(self.activeStage) ~= backupGroup.assignedStageNumber then
                backupGroup:SendRTB()
            end
        end

        --Schedule or reassign primary units if applicable
        for _, primaryGroup in pairs(self.PrimaryCapGroups) do
            local supposedTargetStage = primaryGroup:GetTargetZone(self.activeStage)
            if supposedTargetStage then
                if requiredPerStage[supposedTargetStage] == nil then
                    requiredPerStage[supposedTargetStage] = 0
                end

                if countPerStage[supposedTargetStage] == nil
                then
                    countPerStage[supposedTargetStage] = 0
                end

                requiredPerStage[supposedTargetStage] = requiredPerStage[supposedTargetStage] + 1

                if primaryGroup.state == Spearhead.internal.Air.GroupState.READYONRAMP then
                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        primaryGroup:SendToStageForCap(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                elseif primaryGroup.state == Spearhead.internal.Air.GroupState.INTRANSIT or primaryGroup.state == Spearhead.internal.Air.GroupState.ONSTATION then
                    if supposedTargetStage ~= primaryGroup.assignedStageNumber then
                        if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                            primaryGroup:SendToStageForCap(supposedTargetStage)
                        else
                            countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                            primaryGroup:SendRTB()
                        end
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                elseif primaryGroup.state == Spearhead.internal.Air.GroupState.RTBINTEN and primaryGroup:GetTargetZone(self.activeStage) ~= primaryGroup.assignedStageNumber then
                    primaryGroup:SendRTB()
                end
            else
                primaryGroup:SendRTBAndDespawn()
            end
        end

        for _, backupGroup in pairs(self.BackupCapGroups) do
            if backupGroup.state == Spearhead.internal.Air.GroupState.READYONRAMP then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end

                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        backupGroup:SendToStageForCap(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                else
                    backupGroup:SendRTBAndDespawn()
                end
            end
        end
    end

    o.OnEscortReady = function(self, groupName)
        if self.allGroupsByName[groupName] == nil then
            return
        end

        self.logger:debug("Received ready for escort for group ".. groupName)

        local group = self.allGroupsByName[groupName]
        if group and group.state == Spearhead.internal.Air.GroupState.WAITINGFORESCORT then
            group:SendOutForCas(self.activeStage)
        end
    end

    o.OnStageNumberChanged = function(self, number)
        self.activeStage = number
        self:SpawnIfApplicable()
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 5)
    end

    ---Check if any CAP is active when a certain stage is active
    ---@param self table
    ---@param stageNumber number
    ---@return boolean
    o.IsBaseActiveWhenStageIsActive = function(self, stageNumber)
        for _, group in pairs(self.PrimaryCapGroups) do
            local target = group:GetTargetZone(stageNumber)
            if target ~= nil then
                return true
            end
        end
        return false
    end

    Spearhead.Events.AddStageNumberChangedListener(o)
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.RedBase = RedBase
