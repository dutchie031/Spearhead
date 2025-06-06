---@class CapBase : OnStageChangedListener
---@field private airbaseName string
---@field private logger table
---@field private database Database
---@field private activeStage number
---@field private capConfig table
---@field private capGroupsByName table<string, CapGroup>
---@field private runwayBombingTracker RunwayBombingTracker
---@field private runwayStrikeMissions table<string, RunwayStrikeMission>
local CapBase = {}


local CheckStateContinuous = function(self, time)
    self:CheckAndScheduleCAP()
    return time + 15
end

---comment
---@param airbaseName string
---@param database Database
---@param logger table
---@param capConfig table
---@param stageConfig table
---@param runwayBombingTracker RunwayBombingTracker
---@return CapBase
function CapBase.new(airbaseName, database, logger, capConfig, stageConfig, runwayBombingTracker)
    CapBase.__index = CapBase
    local self = setmetatable({}, { __index = CapBase }) --[[@as CapBase]]

    self.runwayBombingTracker = runwayBombingTracker
    self.runwayStrikeMissions = {}

    self.airbaseName = airbaseName
    self.logger = logger
    self.activeStage = 0
    self.capConfig = capConfig
    self.database = database
    self.capGroupsByName = {}

    local baseData = database:getAirbaseDataForZone(airbaseName)
    if baseData and baseData.CapGroups then
        for key, name in pairs(baseData.CapGroups) do
            local capGroup = Spearhead.classes.capClasses.airGroups.CapGroup.New(name, capConfig, logger)
            if capGroup then
                self.capGroupsByName[name] = capGroup
            end
        end
    end

    logger:info("Airbase with name '" ..
    airbaseName .. "' has a total of " .. Spearhead.Util.tableLength(self.capGroupsByName) .. " cap flights registered")

    self:CreateRunwayStrikeMission(database)

    Spearhead.Events.AddStageNumberChangedListener(self)

    timer.scheduleFunction(CheckStateContinuous, self, timer.getTime() + 15)

    return self
end

---@private
---@param database Database
function CapBase:CreateRunwayStrikeMission(database)
    local airbase = Airbase.getByName(self.airbaseName)
    if not airbase then
        self.logger:debug("Could not find a airbase with name to create runway mission" .. self.airbaseName)
        return
    end

    for _, runway in pairs(airbase:getRunways()) do
        if runway then
            self.logger:debug("Runway " ..
            runway.Name ..
            " at airbase " ..
            self.airbaseName ..
            " with heading " .. runway.course .. " and length " .. runway.length .. " and width " .. runway.width)
            local mission = Spearhead.classes.stageClasses.missions.RunwayStrikeMission.new(runway, self.airbaseName,
            database, self.logger, self.runwayBombingTracker)
            self.runwayStrikeMissions[runway.Name] = mission
        end
    end
end

function CapBase:SpawnIfApplicable()
    self.logger:debug("Check spawns for airbase " .. self.airbaseName)
    for groupName, capGroup in pairs(self.capGroupsByName) do
        local targetStage = capGroup:GetZoneIDWhenStageID(tostring(self.activeStage))

        if targetStage ~= nil and capGroup:GetState() == "UnSpawned" then
            capGroup:Spawn()
        end
    end
end

function CapBase:CheckAndScheduleCAP()
    self.logger:debug("Check taskings for airbase " .. self.airbaseName)

    local countPerStage = {}
    local requiredPerStage = {}

    local airbase = Airbase.getByName(self.airbaseName)
    if not airbase then
        return nil
    end

    local activeStageID = tostring(self.activeStage)

    --Count back up groups that are active or reassign to the new zone if that's needed
    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == true then
            local state = group:GetState()
            if state == "InTransit" or state == "OnStation" or state == "RtbInTen" then
                
                local supposedTargetZoneID = group:GetZoneIDWhenStageID(activeStageID)
                local currentTargetZone = group:GetCurrentTargetZoneID()

                if supposedTargetZoneID == nil then
                    self.logger:debug("CapGroup " .. group:GetName() .. " has no target zone for stage " .. activeStageID)
                    group:SendRTB(airbase)
                else
                    if supposedTargetZoneID and supposedTargetZoneID ~= currentTargetZone then
                        if state == "RtbInTen" then
                            self.logger:debug("CapGroup " .. group:GetName() .. " is RTB in 10 minutes, sending to RTB already")
                            group:SendRTB(airbase)
                        else
                            local triggerZone = self.database:GetCapZoneForZoneID(supposedTargetZoneID)
                            if triggerZone then
                                group:SendToZone(triggerZone, supposedTargetZoneID, airbase)
                            else
                                self.logger:debug("CapGroup " .. group:GetName() .. " has no trigger zone for stage " .. activeStageID)
                                group:SendRTB(airbase)
                            end
                        end
                    end
                    
                    if countPerStage[supposedTargetZoneID] == nil then
                        countPerStage[supposedTargetZoneID] = 0
                    end

                    if supposedTargetZoneID == group:GetCurrentTargetZoneID() and (state == "OnStation" or state =="InTransit") then
                        countPerStage[supposedTargetZoneID] = countPerStage[supposedTargetZoneID] + 1
                    end
                end
            end
        end
    end

    --Schedule or reassign primary units if applicable
    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == false then
            local state = group:GetState()
            local supposedZone = group:GetZoneIDWhenStageID(activeStageID)
            if supposedZone then
                if requiredPerStage[supposedZone] == nil then
                    requiredPerStage[supposedZone] = 0
                end

                if countPerStage[supposedZone] == nil then
                    countPerStage[supposedZone] = 0
                end

                requiredPerStage[supposedZone] = requiredPerStage[supposedZone] + 1

                if state == "ReadyOnTheRamp" then
                    if countPerStage[supposedZone] < requiredPerStage[supposedZone] then
                        local triggerZone = self.database:GetCapZoneForZoneID(supposedZone)
                        if triggerZone then
                            group:SendToZone(triggerZone, supposedZone, airbase)
                        end

                        countPerStage[supposedZone] = countPerStage[supposedZone] + 1
                    end
                elseif state == "InTransit" or state == "OnStation" then
                    
                    if supposedZone ~= group:GetCurrentTargetZoneID() then
                        if countPerStage[supposedZone] < requiredPerStage[supposedZone] then
                            local triggerZone = self.database:GetCapZoneForZoneID(supposedZone)
                            if triggerZone then
                                group:SendToZone(triggerZone, supposedZone, airbase)
                            else
                                group:SendRTB(airbase)
                            end
                        end
                    end
                    countPerStage[supposedZone] = countPerStage[supposedZone] + 1
                elseif state == "RtbInTen" and supposedZone ~= group:GetCurrentTargetZoneID() then
                    group:SendRTB(airbase)
                end
            else
                if state == "InTransit" or state == "OnStation" or state == "RtbInTen" then
                    -- If the group is in transit or on station but has no target zone, send it back to base
                    group:SendRTB(airbase)
                end
            end
        end
    end

    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == true then
            if group:GetState() == "ReadyOnTheRamp" then
                local supposedZone = group:GetZoneIDWhenStageID(activeStageID)
                if supposedZone then
                    if countPerStage[supposedZone] == nil then
                        countPerStage[supposedZone] = 0
                    end

                    if requiredPerStage[supposedZone] == nil then
                        requiredPerStage[supposedZone] = 0
                    end

                    if countPerStage[supposedZone] < requiredPerStage[supposedZone] then
                        local triggerZone = self.database:GetCapZoneForZoneID(supposedZone)
                        if triggerZone then
                            group:SendToZone(triggerZone, supposedZone, airbase)
                        end
                        
                        countPerStage[supposedZone] = countPerStage[supposedZone] + 1
                    end
                end
            end
        end
    end
end

function CapBase:OnStageNumberChanged(number)
    self.activeStage = number

    if self:IsBaseActiveWhenStageIsActive(number) == true then
        for _, mission in pairs(self.runwayStrikeMissions) do
            mission:SpawnActive()
        end
    end
    self:SpawnIfApplicable()
end

---@param stageNumber number
---@return boolean
function CapBase:IsBaseActiveWhenStageIsActive(stageNumber)
    for _, group in pairs(self.capGroupsByName) do
        local target = group:GetZoneIDWhenStageID(tostring(stageNumber))
        if group:IsBackup() == false and target ~= nil then
            return true
        end
    end
    return false
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
Spearhead.classes.capClasses.CapAirbase = CapBase
