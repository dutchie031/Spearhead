
---@alias StageColor
---| "RED"
---| "BLUE"
---| "GRAY"

--- @class StageData
--- @field missionsByCode table<string, Mission>
--- @field missionsByName table<string, Mission>
--- @field missions Array<ZoneMission>
--- @field sams Array<ZoneMission>
--- @field blueSams Array<BlueSam>
--- @field airbases Array<StageBase>
--- @field miscGroups Array<SpearheadGroup>
--- @field maxMissions integer
--- @field farps Array<FarpZone>
--- @field supplyHubs Array<SupplyHub>

--- @class StageInitData
--- @field stageZoneName string
--- @field stageNumber integer
--- @field stageDisplayName string


--- @class StageCompleteListener
--- @field OnStageComplete fun(self:StageCompleteListener, stage:Stage)

--- @class Stage : MissionCompleteListener, OnStageChangedListener
--- @field zoneName string
--- @field stageName string?
--- @field stageNumber number
--- @field protected _isActive boolean
--- @field protected _isComplete boolean
--- @field protected _missionPriority MissionPriority
--- @field protected _database Database
--- @field protected _db StageData
--- @field protected _logger Logger
--- @field protected _preActivated boolean
--- @field protected _activeStage integer
--- @field protected _stageConfig StageConfig
--- @field protected _stageDrawingId integer
--- @field protected _spawnedGroups Array<string>
--- @field protected _stageCompleteListeners Array<StageCompleteListener>
--- @field protected CheckContinuousAsync fun(self:Stage, time:number) : number?
--- @field protected OnPostStageComplete fun(self:Stage)?
--- @field protected OnPostBlueActivated fun(self:Stage)?
local Stage = {}

Stage.__index = Stage


Stage.StageColors = {
    INVISIBLE = { r=0, g=0, b=0, a=0 },
    RED_ACTIVE = { r=1, g=0, b=0, a=0.15 },
    RED_PREACTIVE = { r=1, g=0, b=0, a=0.10},
    BLUE = { r=0, g=0, b=1, a=0.10},
    GRAY = { r=80/255, g=80/255, b=80/255, a=0.10 }
}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger Logger
---@param initData StageInitData
---@param missionPriority MissionPriority
---@param spawnManager SpawnManager
---@return Stage
function Stage:superNew(database, stageConfig, logger, initData, missionPriority, spawnManager)

    logger:debug("[BaseStage] Initiating stage with name: " .. initData.stageZoneName)

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup

    self.zoneName = initData.stageZoneName
    self.stageNumber = initData.stageNumber
    self._isActive = false
    self._isComplete = false
    self.stageName = initData.stageDisplayName
    
    self.OnPostStageComplete = nil
    self.OnPostBlueActivated = nil

    self._database = database
    self._logger = logger
    self._db = {
        missionsByCode = {},
        missions = {},
        sams ={},
        blueSams = {},
        airbases ={},
        miscGroups = {},
        maxMissions = stageConfig.maxMissionsPerStage,
        farps = {},
        missionsByName = {},
        supplyHubs = {}
    }

    self._activeStage = -99
    self._preActivated = false
    self._stageConfig = stageConfig or {}

    local zone = Spearhead.DcsUtil.getZoneByName(self.zoneName)
    if zone then
        self._stageDrawingId = Spearhead.DcsUtil.DrawZone(zone, Stage.StageColors.INVISIBLE, Stage.StageColors.INVISIBLE, 4)
    end

    self._spawnedGroups = {}
    self._missionPriority = missionPriority
    self._stageCompleteListeners = {}

    local farpNames = database:getFarpNamesInStage(self.zoneName)
    for _, farpName in pairs(farpNames) do
        local farp = Spearhead.classes.stageClasses.SpecialZones.FarpZone.New(database, logger, farpName, spawnManager)
        table.insert(self._db.farps, farp)
    end

    local supplyHubNames = database:getSupplyHubsInStage(self.zoneName)
    for _, supplyHubName in pairs(supplyHubNames) do
        local supplyHub = Spearhead.classes.stageClasses.SpecialZones.SupplyHub.new(database, logger, supplyHubName)
        table.insert(self._db.supplyHubs, supplyHub)
    end

    self._logger:info("Initiating new Stage with name: " .. self.zoneName)

    ---comment
    ---@param self Stage
    ---@param time number?
    self.CheckContinuousAsync = function (self, time)
        
        self:CheckAndUpdateSelf()
        if self:IsComplete() == true then
            self:NotifyComplete()
            return nil
        end

        return time + 20
    end
    

    do -- load tables
        local missionZones = database:getMissionsForStage(self.zoneName)
        self._logger:debug("Found " .. Spearhead.Util.tableLength(missionZones) .. " mission zones for stage: " .. self.zoneName)
        for _, missionZone in pairs(missionZones) do
            
            local mission = Spearhead.classes.stageClasses.missions.ZoneMission.new(missionZone, self._missionPriority, database, logger, self, spawnManager)
            if mission then
                self._db.missionsByCode[mission.code] = mission

                if mission.name and self._db.missionsByName[mission.name] == nil then
                    self._db.missionsByName[mission.name] = mission
                else
                    Spearhead.AddMissionEditorWarning("DUPLICATE MISSION NAME ALERT: " .. mission.name .. " in zone: " .. self.zoneName)
                end

                if mission.missionType == "SAM" then
                    table.insert(self._db.sams, mission)
                else
                    table.insert(self._db.missions, mission)
                end
            end
        end

        local randomMissionNames = database:getRandomMissionsForStage(self.zoneName)

        ---@type table<string, Array<Mission>>
        local randomMissionByName = {}
        for _, missionZoneName in pairs(randomMissionNames) do
            local mission = Spearhead.classes.stageClasses.missions.ZoneMission.new(missionZoneName, self._missionPriority, database, logger, self, spawnManager)
            if mission then
                if randomMissionByName[mission.name] == nil then
                    randomMissionByName[mission.name] = {}
                end
                table.insert(randomMissionByName[mission.name], mission)
            end
        end

        for missionName, missions in pairs(randomMissionByName) do

            local missionZonePicked = Spearhead.classes.persistence.Persistence.GetPickedRandomMission(missionName)
            if missionZonePicked == nil then
                local mission = Spearhead.Util.randomFromList(missions) --[[@as Mission]]
                if mission then
                    Spearhead.classes.persistence.Persistence.RegisterPickedRandomMission(mission.name, mission.zoneName)

                    self._db.missionsByCode[mission.code] = mission

                    if mission.name and self._db.missionsByName[mission.name] == nil then
                        self._db.missionsByName[mission.name] = mission
                    else
                        Spearhead.AddMissionEditorWarning("DUPLICATE MISSION NAME ALERT: " .. mission.name .. " in zone: " .. self.zoneName)
                    end

                    if mission.missionType == "SAM" then
                        table.insert(self._db.sams, mission)
                    else
                        table.insert(self._db.missions, mission)
                    end
                end
            else 
                self._logger:info("Using persisted random mission with name: " .. missionName .. " and zone: " .. missionZonePicked)
                for _, mission in pairs(missions) do
                    if string.lower(mission.zoneName) == string.lower(missionZonePicked) then
                        self._db.missionsByCode[mission.code] = mission
                        if mission.missionType == "SAM" then
                            table.insert(self._db.sams, mission)
                        else
                            table.insert(self._db.missions, mission)
                        end
                    end
                end
            end
        end

        for _, mission in pairs(self._db.missionsByCode) do
            mission:AddMissionCompleteListener(self)
        end

        local airbaseNames = database:getAirbaseNamesInStage(self.zoneName)
        if airbaseNames ~= nil and type(airbaseNames) == "table" then
            for _, airbaseName in pairs(airbaseNames) do
                local airbase = Spearhead.classes.stageClasses.SpecialZones.StageBase.New(database, logger, airbaseName, spawnManager)
                table.insert(self._db.airbases, airbase)
            end
        end

        for _, samZoneName in pairs(database:getBlueSamsInStage(self.zoneName)) do
            local blueSam =  Spearhead.classes.stageClasses.SpecialZones.BlueSam.New(database, logger, samZoneName, spawnManager)
            table.insert(self._db.blueSams, blueSam)
        end

        local miscGroups = database:getMiscGroupsAtStage(self.zoneName)
        for _, groupName in pairs(miscGroups) do
            local miscGroup = SpearheadGroup.New(groupName, spawnManager, true)

            table.insert(self._db.miscGroups, miscGroup)
            miscGroup:Destroy()
        end
    end

    Spearhead.Events.AddStageNumberChangedListener(self)
        
    return self
end

---@return boolean
function Stage:IsComplete()
    if self._isComplete == true then return true end

    for i, mission in pairs(self._db.sams) do
        local state = mission:getState()
        if state == "ACTIVE" or state == "NEW" or state =="WAITING" then
            return false
        end
    end

    for i, mission in pairs(self._db.missions) do
        local state = mission:getState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end

    self._isComplete = true
    return true
end

---@return boolean
function Stage:IsActive()
    return self._isActive == true
end

---comment
function Stage:CheckAndUpdateSelf()
    self._logger:debug("Checking on Stage: " .. self.zoneName)

    local dbTables = self:GetStageTables()

    ---@return Array<Mission>
    local getAvailableMissions = function ()
        ---@type Array<Mission>
        local availableMissions = {}
        for _, mission in pairs(dbTables.missionsByCode) do
            if mission:getState() == "NEW" then
                table.insert(availableMissions, mission)
            end
        end
        return availableMissions
    end

    ---@return number
    local getActiveMissionsCount = function ()
        local result = 0
        for _, mission in pairs(dbTables.missionsByCode) do
            if mission:getState() == "ACTIVE" then
                result = result + 1
            end
        end
        return result
    end

    local max = dbTables.maxMissions
    local availableMissionsCount = Spearhead.Util.tableLength(getAvailableMissions())
    local activeCount = getActiveMissionsCount()
    if activeCount < max and availableMissionsCount > 0  then
        for i = activeCount+1, max do
            if availableMissionsCount == 0 then
                i = max+1 --exits this loop
            else
                local mission = Spearhead.Util.randomFromList(getAvailableMissions()) --[[@as Mission]]
                if mission then
                    mission:SpawnActive()
                    activeCount = activeCount + 1;
                else
                    return
                end
                availableMissionsCount = availableMissionsCount - 1
            end
        end
    end
end

---@param missionName string
---@return boolean
function Stage:IsMissionComplete(missionName)

    local mission = self._db.missionsByName[missionName]
    if not mission then return true end

    return mission:getState() == "COMPLETED"
end

---private use only
function Stage:NotifyComplete()

    self._logger:info("Stage complete: " .. (self.stageName or self.stageNumber or "unknown"))

    for _, listener in pairs(self._stageCompleteListeners) do
        pcall(function()
            listener:OnStageComplete(self)
        end)
    end

    if self.OnPostStageComplete then
        timer.scheduleFunction(self.OnPostStageComplete, self, timer.getTime() + 3)
    end
end

---@param listener StageCompleteListener
function Stage:AddStageCompleteListener(listener)
    table.insert(self._stageCompleteListeners, listener)
end

---Activates all SAMS, Airbase units etc all at once.
---@param draw boolean
function Stage:PreActivate(draw)
    if self._preActivated == false then
        self._preActivated = true
        for key, mission in pairs(self._db.sams) do
            if mission then
                mission:SpawnInactive()
            end
        end

        for _, airbase in pairs(self._db.airbases) do
            airbase:ActivateRedStage()
        end
    end

    if draw == true then
        self:MarkStage(Stage.StageColors.RED_PREACTIVE)
    end

end

---@param stageColor DrawColor
function Stage:MarkStage(stageColor)
    local lineColor = { r=stageColor.r, g=stageColor.g, b=stageColor.b, a=stageColor.a }
    local fillColor = { r=stageColor.r, g=stageColor.g, b=stageColor.b, a=stageColor.a }

    if stageColor.a > 0 then
        lineColor.a = 1
    end

    if stageColor == Stage.StageColors.RED_PREACTIVE then
        lineColor.a = 0
    end

    if self._stageDrawingId and self._stageConfig.isDrawStagesEnabled == true then
        Spearhead.DcsUtil.SetLineColor(self._stageDrawingId, lineColor)
        Spearhead.DcsUtil.SetFillColor(self._stageDrawingId, fillColor)
    end
end

function Stage:ActivateStage()
    self._isActive = true;

    pcall(function()
        self:MarkStage(Stage.StageColors.RED_ACTIVE)
    end)

    self:PreActivate(false)
    
    self._logger:debug("Activating Misc groups for zone. Count: " .. Spearhead.Util.tableLength(self._db.miscGroups))
    for _, miscGroup in pairs(self._db.miscGroups) do
        miscGroup:Spawn()
    end

    for _, mission in pairs(self._db.missions) do
        if mission.missionType == "DEAD" then
            mission:SpawnActive()
        end
    end

    for _, farp in pairs(self._db.farps) do
        if farp:IsStartingFarp() == true then
            farp:Activate()
        end
    end

    for _, supplyHub in pairs(self._db.supplyHubs) do
        if supplyHub:IsActiveFromStart() == true then
            supplyHub:Activate()
        end
    end

    timer.scheduleFunction(self.CheckContinuousAsync, self, timer.getTime() + 3)
end

---Private usage only
---@return StageData
function Stage:GetStageTables()
    return self._db
end

---comment
---@param self Stage
---@param number integer
function Stage:OnStageNumberChanged(number)

    if self._activeStage == number then --only activate once for a stage
        return
    end

    local previousActive = self._activeStage
    self._activeStage = number

    if self.stageNumber - self._activeStage  == self._stageConfig.AmountPreactivateStage then
        self._logger:debug("Pre-activating stage: " .. self.zoneName .. " with number: " .. number)
        self:PreActivate(true)
    elseif Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
        self:PreActivate(false)
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

function Stage:GetBriefing()
    return "Briefing For "
end

---@param self Stage
---@param mission Mission
Stage.OnMissionComplete = function(self, mission)
    self:CheckAndUpdateSelf()
end


---private use only
function Stage:ActivateBlueGroups()

    for _, blueSam in pairs(self._db.blueSams) do
        blueSam:Activate()
    end

    for _, airbase in pairs(self._db.airbases) do
        airbase:ActivateBlueStage()
    end

    if self.OnPostBlueActivated then
        pcall(function()
            self:OnPostBlueActivated()
        end)
    end

    for _, farp in pairs(self._db.farps) do
        if farp:IsStartingFarp() == true then
            farp:Activate()
        end
    end

    for _, supplyHub in pairs(self._db.supplyHubs) do
        supplyHub:Activate()
    end
end

---@return number strike
---@return number dead
---@return number bai
---@return number cas
function Stage:GetStageStats()

    local strike = 0
    local dead = 0
    local bai = 0
    local cas = 0

    for _, mission in pairs(self._db.missions) do
        if mission.missionType == "STRIKE" then
            strike = strike + 1
        elseif mission.missionType == "DEAD" or mission.missionType == "SAM" then
            dead = dead + 1
        elseif mission.missionType == "BAI" then
            bai = bai + 1
        elseif mission.missionType == "CAS" then
            cas = cas + 1
        end
    end

    for _, mission in pairs(self._db.sams) do
        dead = dead + 1
    end

    return strike, dead, bai, cas

end

function Stage:ActivateBlueStage()

    self._logger:debug("Setting stage '" .. Spearhead.Util.toString(self.zoneName) .. "' to blue")
    
    for _, mission in pairs(self._db.missions) do
        mission:SpawnPersistedState()
    end

    for _, mission in pairs(self._db.sams) do
        mission:SpawnPersistedState()
    end

    for _, miscGroup in pairs(self._db.miscGroups) do
        miscGroup:Spawn()
    end

    ---@param self Stage
    local ActivateBlueAsync = function(self)
        pcall(function()
            self:MarkStage(Stage.StageColors.BLUE)
        end)

        self:ActivateBlueGroups()

        return nil
    end

    timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
if not Spearhead.classes.stageClasses.Stages.BaseStage then Spearhead.classes.stageClasses.Stages.BaseStage = {} end
Spearhead.classes.stageClasses.Stages.BaseStage.Stage = Stage






