---@class CapBase : OnStageChangedListener
---@field groupNames Array<string>
---@field database Database
---@field airbaseName string
---@field logger table
---@field activeStage number
---@field capConfig table
---@field activeCapStages number
---@field lastStatesByName table<string, string>
---@field groupsByName table<string, CapGroup>
---@field PrimaryGroups Array<CapGroup>
---@field BackupGroups Array<CapGroup>
local CapBase = {}


local CheckReschedulingAsync = function(self, time)
    self:CheckAndScheduleCAP()
end

---comment
---@param airbaseName string
---@param database Database
---@param logger table
---@param capConfig table
---@param stageConfig table
---@return CapBase
function CapBase.new(airbaseName, database, logger, capConfig, stageConfig)
    
    CapBase.__index = CapBase
    local self = setmetatable({}, { __index = CapBase }) --[[@as CapBase]]

    self.groupNames = database:getCapGroupsAtAirbase(airbaseName)
    self.database  = database
    
    self.airbaseName = airbaseName
    self.logger = logger
    self.activeStage = 0
    self.capConfig = capConfig
    self.activeCapStages = (stageConfig or {}).capActiveStages or 10

    self.lastStatesByName = {}
    self.groupsByName = {}
    self.PrimaryGroups = {}
    self.BackupGroups = {}

    for key, name in pairs(self.groupNames) do
        local capGroup = Spearhead.internal.CapGroup.new(name, airbaseName, logger, database, capConfig)
        if capGroup then
            self.groupsByName[name] = capGroup

            if capGroup.isBackup ==true then
                table.insert(self.BackupGroups, capGroup)
            else
                table.insert(self.PrimaryGroups, capGroup)
            end

            capGroup:AddOnStateUpdatedListener(self)
        end
    end
    logger:info("Airbase with name '" .. airbaseName .. "' has a total of " .. Spearhead.Util.tableLength(self.groupsByName) .. "cap flights registered")


    Spearhead.Events.AddStageNumberChangedListener(self)

   return self
end

function CapBase:onGroupStateUpdated(capGroup)
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

function CapBase:SpawnIfApplicable()
        self.logger:debug("Check spawns for airbase " .. self.airbaseName )
        for groupName, capGroup in pairs(self.groupsByName) do
            
            local targetStage = capGroup:GetTargetZone(self.activeStage)

            if targetStage ~= nil and capGroup.state == Spearhead.internal.CapGroup.GroupState.UNSPAWNED then
                capGroup:SpawnOnTheRamp()
            end
        end
    end

function CapBase:CheckAndScheduleCAP()

        self.logger:debug("Check taskings for airbase " .. self.airbaseName )
        
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

function CapBase:OnStageNumberChanged(number)
    self.activeStage = number
    self:SpawnIfApplicable()
    timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 5)
end


---@param stageNumber number
---@return boolean
function CapBase:IsBaseActiveWhenStageIsActive(stageNumber)
    for _, group in pairs(self.PrimaryGroups) do
        local target = group:GetTargetZone(stageNumber)
        if target ~= nil then
            return true
        end
    end
    return false
end


if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.CapAirbase = CapBase