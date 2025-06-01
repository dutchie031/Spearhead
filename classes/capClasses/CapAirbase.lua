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
        local targetStage = capGroup:GetZoneIDWhenStageID(self.activeStage)

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

    --Count back up groups that are active or reassign to the new zone if that's needed
    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == true then
            local state = group:GetState()
            if state == "InTransit" or state == "OnStation" or state == "RtbInTen" then
                
                local supposedTargetZoneID = group:GetZoneIDWhenStageID(self.activeStage)
                local currentTargetZone = group:GetCurrentTargetZoneID()

                if supposedTargetZoneID == nil then
                    self.logger:debug("CapGroup " .. group:GetName() .. " has no target zone for stage " .. self.activeStage)
                    group:SendRTB(airbase)
                end

                if supposedTargetZoneID and supposedTargetZoneID ~= currentTargetZone then
                    if state == "RtbInTen" then
                        self.logger:debug("CapGroup " .. group:GetName() .. " is RTB in 10 minutes, sending to RTB already")
                        group:SendRTB(airbase)
                    else
                        local triggerZone = self.database:GetCapZoneForZoneID(tostring(supposedTargetZoneID))
                        if triggerZone then
                            group:SendToZone(triggerZone, supposedTargetZoneID, airbase)
                        else
                            self.logger:debug("CapGroup " .. group:GetName() .. " has no trigger zone for stage " .. self.activeStage)
                            group:SendRTB(airbase)
                        end
                    end
                end
                
                if countPerStage[tostring(supposedTargetZoneID)] == nil then
                    countPerStage[tostring(supposedTargetZoneID)] = 0
                end

                if supposedTargetZoneID == group:GetCurrentTargetZoneID() then
                    countPerStage[tostring(supposedTargetZoneID)] = countPerStage[tostring(supposedTargetZoneID)] + 1
                end
            end
        end
    end

    --Schedule or reassign primary units if applicable
    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == false then
            self.logger:debug("CapGroup " .. group:GetName() .. " is a primary group, checking state")
            local state = group:GetState()
            local supposedZone = group:GetZoneIDWhenStageID(self.activeStage)
            if supposedZone then
                if requiredPerStage[tostring(supposedZone)] == nil then
                    requiredPerStage[tostring(supposedZone)] = 0
                end

                if countPerStage[tostring(supposedZone)] == nil then
                    countPerStage[tostring(supposedZone)] = 0
                end

                requiredPerStage[tostring(supposedZone)] = requiredPerStage[tostring(supposedZone)] + 1

                if state == "ReadyOnTheRamp" then
                    self.logger:debug("CapGroup " .. group:GetName() .. " is ready on the ramp, checking if it needs to be sent to zone")
                    if countPerStage[tostring(supposedZone)] < requiredPerStage[tostring(supposedZone)] then
                        
                        self.logger:debug("CapGroup " .. group:GetName() .. " is ready on the ramp, sending to zone")

                        local triggerZone = self.database:GetCapZoneForZoneID(tostring(supposedZone))
                        if triggerZone then
                            group:SendToZone(triggerZone, supposedZone, airbase)
                        end

                        countPerStage[tostring(supposedZone)] = countPerStage[tostring(supposedZone)] + 1
                    end
                elseif state == "InTransit" or state == "OnStation" then
                    
                    if supposedZone ~= group:GetCurrentTargetZoneID() then
                        if countPerStage[tostring(supposedZone)] < requiredPerStage[tostring(supposedZone)] then
                            local triggerZone = self.database:GetCapZoneForZoneID(tostring(supposedZone))
                            if triggerZone then
                                group:SendToZone(triggerZone, supposedZone, airbase)
                            else
                                self.logger:debug("CapGroup " .. group:GetName() .. " has no trigger zone for stage " .. self.activeStage)
                                group:SendRTB(airbase)
                            end
                        end
                    end
                    countPerStage[tostring(supposedZone)] = countPerStage[tostring(supposedZone)] + 1
                elseif state == "RtbInTen" and supposedZone ~= group:GetCurrentTargetZoneID() then
                    self.logger:debug("CapGroup " .. group:GetName() .. " is RTB in 10 minutes, sending to RTB already")
                    group:SendRTB(airbase)
                end
            else
                if state == "InTransit" or state == "OnStation" or state == "RtbInTen" then
                    -- If the group is in transit or on station but has no target zone, send it back to base
                    group:SendRTB(airbase)
                end
                 self.logger:debug("CapGroup " .. group:GetName() .. " has no target zone for stage " .. self.activeStage)
            end
        end
    end

    for _, group in pairs(self.capGroupsByName) do
        if group:IsBackup() == true then
            if group:GetState() == "ReadyOnTheRamp" then
                local supposedZone = group:GetZoneIDWhenStageID(self.activeStage)
                if supposedZone then
                    if countPerStage[tostring(supposedZone)] == nil then
                        countPerStage[tostring(supposedZone)] = 0
                    end

                    if countPerStage[tostring(supposedZone)] < requiredPerStage[tostring(supposedZone)] then
                        local triggerZone = self.database:GetCapZoneForZoneID(tostring(supposedZone))
                        if triggerZone then
                            group:SendToZone(triggerZone, supposedZone, airbase)
                        end
                        
                        countPerStage[tostring(supposedZone)] = countPerStage[tostring(supposedZone)] + 1
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
        local target = group:GetZoneIDWhenStageID(stageNumber)
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
