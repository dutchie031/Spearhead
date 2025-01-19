
---@alias StageColor
---| "RED"
---| "BLUE"
---| "GRAY"

--- @class StageData
--- @field missionsByCode table<string, Mission>
--- @field missions Array<Mission>
--- @field sams Array<Mission>
--- @field blueSams Array<BlueSam>
--- @field airbases Array<StageBase>
--- @field miscGroups Array<SpearheadGroup>
--- @field maxMissions integer

--- @class StageInitData
--- @field stageZoneName string
--- @field stageNumber integer
--- @field stageDisplayName string


--- @class StageCompleteListener
--- @field OnStageComplete fun(self:StageCompleteListener, stage:Stage)

--- @class Stage : MissionCompleteListener, OnStageChangedListener
--- @field zoneName string
--- @field stageName string
--- @field stageNumber number
--- @field isActive boolean
--- @field protected isComplete boolean
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
--- @fiedl protected _stageCompleteListeners Array<StageCompleteListener>
local Stage = {}

local stageDrawingId = 100

---comment
---@generic T: Stage
---@param o T
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@param missionPriority MissionPriority
---@return T
function Stage.New(o, database, stageConfig, logger, initData, missionPriority)

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup

    Stage.__index = Stage
    o = o or {}
    local self = setmetatable(o, Stage)

    self.zoneName = initData.stageZoneName
    self.stageNumber = initData.stageNumber
    self.isActive = false
    self.isComplete = false
    self.stageName = initData.stageDisplayName
    

    self._database = database
    self._logger = logger
    self._db = {
        missionsByCode = {},
        missions = {},
        sams ={},
        blueSams = {},
        airbases ={},
        miscGroups = {},
        maxMissions = stageConfig.maxMissionsPerStage
    }
    self._activeStage = -99
    self._preActivated = false
    self._stageConfig = stageConfig or {}
    self._stageDrawingId = stageDrawingId + 1
    self._spawnedGroups = {}
    self._missionPriority = missionPriority
    self._stageCompleteListeners = {}

    stageDrawingId = stageDrawingId + 1

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
        for _, missionZone in pairs(missionZones) do
            local mission = Spearhead.classes.stageClasses.Missions.Mission.New(missionZone, self._missionPriority, database, logger)
            if mission then
                self._db.missionsByCode[mission.code] = mission
                if mission.missionType == "SAM" then
                    table.insert(self._db.sams, mission)
                else
                    table.insert(self._db.missions, mission)
                end
            end
        end

        local randomMissionNames = database:getRandomMissionsForStage(self.zoneName)

        local randomMissionByName = {}
        for _, missionZoneName in pairs(randomMissionNames) do
            local mission = Spearhead.classes.stageClasses.Missions.Mission.New(missionZoneName, "primary", database, logger)
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
            mission:AddMissionCompleteListener(self)
        end

        local airbaseIds = database:getAirbaseIdsInStage(self.zoneName)
        if airbaseIds ~= nil and type(airbaseIds) == "table" then
            for _, airbaseId in pairs(airbaseIds) do
                local airbase = Spearhead.classes.stageClasses.SpecialZones.StageBase:New(database, logger, airbaseId)
                table.insert(self._db.airbases, airbase)
            end
        end

        for _, samZoneName in pairs(database:getBlueSamsInStage(self.zoneName)) do
            local blueSam =  Spearhead.classes.stageClasses.SpecialZones.BlueSam:new(database, logger, samZoneName)
            table.insert(self._db.blueSams, blueSam)
        end

        local miscGroups = database:getMiscGroupsAtStage(self.zoneName)
        for _, groupName in pairs(miscGroups) do
            local miscGroup = SpearheadGroup.New(groupName)

            table.insert(self._db.miscGroups, miscGroup)
            Spearhead.DcsUtil.DestroyGroup(groupName)
        end
    end

    Spearhead.Events.AddStageNumberChangedListener(self)
        
    return self
end

---@return boolean
function Stage:IsComplete()
    if self.isComplete == true then return true end

    for i, mission in pairs(self._db.sams) do
        local state = mission:GetState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end

    for i, mission in pairs(self._db.missions) do
        local state = mission:GetState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end

    self.isComplete = true
    return true
end

---comment
function Stage:CheckAndUpdateSelf()
    self._logger:debug("Checking on Stage: " .. self.zoneName)

    local activeCount = 0
    local dbTables = self:GetStageTables()

    local availableMissions = {}
    for _, mission in pairs(dbTables.missionsByCode) do
        local state = mission:GetState()

        if state == "ACTIVE" then
            activeCount = activeCount + 1
        end

        if state == "NEW" then
            table.insert(availableMissions, mission)
        end
    end

    local max = dbTables.maxMissions
    local availableMissionsCount = Spearhead.Util.tableLength(availableMissions)
    if activeCount < max and availableMissionsCount > 0  then
        for i = activeCount+1, max do
            if availableMissionsCount == 0 then
                i = max+1 --exits this loop
            else
                local index = math.random(1, availableMissionsCount)

                ---@type Mission
                local mission = table.remove(availableMissions, index)
                if mission then
                    mission:SpawnActive()
                    activeCount = activeCount + 1;
                end
                availableMissionsCount = availableMissionsCount - 1
            end
        end
    end
end

---private use only
function Stage:NotifyComplete()

    self._logger:info("Stage complete: " .. self.stageName)

    for _, listener in pairs(self._stageCompleteListeners) do
        pcall(function()
            listener:OnStageComplete(self)
        end)
    end

end

---@param listener StageCompleteListener
function Stage:AddStageCompleteListener(listener)
    table.insert(self._stageCompleteListeners, listener)
end

---Activates all SAMS, Airbase units etc all at once.
function Stage:PreActivate()
    if self._preActivated == false then
        self._preActivated = true
        for key, mission in pairs(self._db.sams) do
            if mission then
                mission:SpawnActive()
            end
        end

        for _, airbase in pairs(self._db.airbases) do
            airbase:ActivateRedStage()
        end
    end
end

---@param stageColor StageColor
function Stage:MarkStage(stageColor)
    local fillColor = {1, 0, 0, 0.1}
    local line ={ 1, 0,0, 1 }

    if stageColor == "RED" then
        fillColor = {1, 0, 0, 0.1}
        line ={ 1, 0,0, 1 }
    elseif stageColor =="BLUE" then
        fillColor = {0, 0, 1, 0.1}
        line ={ 0, 0,1, 1 }
    else
        fillColor = {80/255, 80/255, 80/255, 0.3}
        line ={ 80/255, 80/255,80/255, 1 }
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

function Stage:ActivateStage()
    self.isActive = true;

    pcall(function()
        self:MarkStage("RED")
    end)

    self:PreActivate()
    
    self._logger:debug("Activating Misc groups for zone. Count: " .. Spearhead.Util.tableLength(self._db.miscGroups))
    for _, miscGroup in pairs(self._db.miscGroups) do
        miscGroup:Spawn()
    end

    for _, mission in pairs(self._db.missions) do
        if mission.missionType == "DEAD" then
            mission:SpawnActive()
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

function Stage:GetBriefing()
    return "Briefing For "
end

---@param self Stage
---@param mission Mission
Stage.OnMissionComplete = function(self, mission)
    self:CheckAndUpdateSelf()
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
            self:MarkStage("BLUE")
        end)

        local _db = self:GetStageTables()

        for _, blueSam in pairs(_db.blueSams) do
            blueSam:Activate()
        end

        for _, airbase in pairs(_db.airbases) do
            airbase:ActivateBlueStage()
        end

        return nil
    end

    timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.__Stage = Stage






