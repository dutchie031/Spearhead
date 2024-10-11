
local CapBase = {}

---comment
---@param airbaseId number
---@param database table
---@param logger table
---@param capConfig table
---@param stageConfig table
---@return table
function CapBase:new(airbaseId, database, logger, capConfig, stageConfig)
    local o  = {}
    setmetatable(o, { __index = self })

    o.groupNames = database:getCapGroupsAtAirbase(airbaseId)
    o.database  = database
    o.airbaseId = airbaseId
    o.logger = logger
    o.activeStage = 0
    o.capConfig = capConfig

    if capConfig == nil then
        capConfig = {}
        Spearhead.AddMissionEditorWarning("CapConfig is nil")
    else
        if capConfig.minSpeed == nil then Spearhead.AddMissionEditorWarning("CapConfig.minSpeed is nil") end
        if capConfig.maxSpeed == nil then Spearhead.AddMissionEditorWarning("CapConfig.maxSpeed is nil") end
        if capConfig.minAlt == nil then Spearhead.AddMissionEditorWarning("CapConfig.minAlt is nil") end
        if capConfig.maxAlt == nil then Spearhead.AddMissionEditorWarning("CapConfig.maxAlt is nil") end
        if capConfig.minDurationOnStation == nil then Spearhead.AddMissionEditorWarning("CapConfig.minDurationOnStation is nil") end
        if capConfig.maxDurationOnStation == nil then Spearhead.AddMissionEditorWarning("CapConfig.maxDurationOnStation is nil") end
        if capConfig.rearmDelay == nil then Spearhead.AddMissionEditorWarning("CapConfig.rearmDelay is nil") end
        if capConfig.deathDelay == nil then Spearhead.AddMissionEditorWarning("CapConfig.deathDelay is nil") end
    end

    o.activeCapStages = (stageConfig or {}).capActiveStages or 10

    o.lastStatesByName = {}
    o.groupsByName = {}
    o.PrimaryGroups = {}
    o.BackupGroups = {}

    local CheckReschedulingAsync = function(self, time)
        self:CheckAndScheduleCAP()
    end

    o.OnGroupStateUpdated = function (self, capGroup)
        --[[
            There is no update needed for INTRANSIT, ONSTATION or REARMING as the PREVIOUS state already was checked and nothing changes in the actual overal state.
        ]]--
        if  capGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT 
            or capGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION 
            or capGroup.state == Spearhead.internal.CapGroup.GroupState.REARMING
        then
            return
        end
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 1)
    end

    for key, name in pairs(o.groupNames) do
        local capGroup = Spearhead.internal.CapGroup:new(name, airbaseId, logger, database, capConfig)
        if capGroup then
            o.groupsByName[name] = capGroup

            if capGroup.isBackup ==true then
                table.insert(o.BackupGroups, capGroup)
            else
                table.insert(o.PrimaryGroups, capGroup)
            end

            capGroup:AddOnStateUpdatedListener(o)
        end
    end

    o.SpawnIfApplicable = function(self)
        self.logger:debug("Check spawns for airbase " .. self.airbaseId )
        for groupName, capGroup in pairs(self.groupsByName) do
            
            local activeStage = tostring(self.activeStage)
            local targetStage = capGroup:GetTargetZone(activeStage)

            if targetStage ~= nil and capGroup.state == Spearhead.internal.CapGroup.GroupState.UNSPAWNED then
                capGroup:SpawnOnTheRamp()
            end
        end
    end

    o.CheckAndScheduleCAP = function (self)

        self.logger:debug("Check taskings for airbase " .. self.airbaseId )
        
        local countPerStage = {}
        local requiredPerStage = {}

        --Count back up groups that are active or reassign to the new zone if that's needed
        for _, backupGroup in pairs(self.BackupGroups) do
            if backupGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT or backupGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if supposedTargetStage ~= backupGroup.assignedStageNumber then
                        backupGroup:SendToStage(supposedTargetStage)
                    end
    
                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                else
                    backupGroup:SendRTBAndDespawn()
                end
            elseif backupGroup.state == Spearhead.internal.CapGroup.GroupState.RTBINTEN and backupGroup:GetTargetZone(self.activeStage) ~= backupGroup.assignedStageNumber then
                backupGroup:SendRTB()
            end
        end

        --Schedule or reassign primary units if applicable
        for _, primaryGroup in pairs(self.PrimaryGroups) do
            local supposedTargetStage = primaryGroup:GetTargetZone(self.activeStage)
            if supposedTargetStage then
                if requiredPerStage[supposedTargetStage] == nil then
                    requiredPerStage[supposedTargetStage] = 0
                end

                if countPerStage[supposedTargetStage] == nil
                 then
                    countPerStage[supposedTargetStage] = 0
                end

                requiredPerStage[supposedTargetStage] =  requiredPerStage[supposedTargetStage] + 1

                if primaryGroup.state == Spearhead.internal.CapGroup.GroupState.READYONRAMP then
                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        primaryGroup:SendToStage(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                elseif primaryGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT or primaryGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION then
                    if supposedTargetStage ~= primaryGroup.assignedStageNumber then
                        if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                            primaryGroup:SendToStage(supposedTargetStage)
                        else
                            countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                            primaryGroup:SendRTB()
                        end
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                elseif primaryGroup.state == Spearhead.internal.CapGroup.GroupState.RTBINTEN and primaryGroup:GetTargetZone(self.activeStage) ~= primaryGroup.assignedStageNumber then
                    primaryGroup:SendRTB()
                end
            else
                primaryGroup:SendRTBAndDespawn()
            end
        end

        for _, backupGroup in pairs(self.BackupGroups) do
            if backupGroup.state == Spearhead.internal.CapGroup.GroupState.READYONRAMP then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end
    
                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        backupGroup:SendToStage(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                else
                    backupGroup:SendRTBAndDespawn()
                end
            end
        end
    end

    o.OnStageNumberChanged = function (self, number)
        self.activeStage = number
        self:SpawnIfApplicable()
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 5)
    end

    ---Check if any CAP is active when a certain stage is active
    ---@param self table
    ---@param stageNumber number
    ---@return boolean
    o.IsBaseActiveWhenStageIsActive = function (self, stageNumber)
        for _, group in pairs(self.PrimaryGroups) do
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
Spearhead.internal.CapAirbase = CapBase