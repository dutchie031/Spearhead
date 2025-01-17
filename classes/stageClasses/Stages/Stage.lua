--- @class StageData
--- @field missionsByCode table<string, Mission>
--- @field missions Array<Mission>
--- @field sams Array<Mission>
--- @field blueSams Array<BlueSam>
--- @field airbases Array<StageBase>

--- @class StageInitData
--- @field stageZoneName string
--- @field stageNumber integer
--- @field stageDisplayName string

--- @class Stage : MissionCompleteListener
--- @field zoneName string
--- @field stageName string
--- @field stageNumber number
--- @field isActive boolean
--- @field isComplete boolean
--- @field private _database Database
--- @field private _db StageData
--- @field private _preActivated boolean
--- @field private _activeStage integer
--- @field private _stageConfig StageConfig
--- @field private _stageDrawingId integer
--- @field private _spawnedGroups Array<string>
--- @field private _stageCompleteListeners Array<StageCompleteListener>

local Stage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return Stage
function Stage:New(database, stageConfig, logger, initData)
    Stage.__index = Stage
    local self = setmetatable({}, Stage)

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

    local randomMissionNames = database:getRandomMissionsForStage(self.zoneName)

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
        mission:AddMissionCompleteListener(self)
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


    return self
end

---@return boolean
function Stage:IsComplete()
    for i, mission in pairs(self._db.missions) do
        local state = mission:GetState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end
    return true
end

---Activates all SAMS, Airbase units etc all at once.
function Stage:PreActivate()
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




---@private
function Stage:_triggerStageCompleteListeners()
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

---@param mission Mission
function Stage:OnMissionComplete(mission)
    if(self:IsComplete()) then
        timer.scheduleFunction(triggerStageCompleteListeners, self, timer.getTime() + 15)
    else
        timer.scheduleFunction(activateMissionsIfApplicableAsync, self, timer.getTime() + 10)
    end
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.__Stage = Stage






