---@class StageBase : BuildableZone
---@field private _database Database
---@field private _logger Logger
---@field private _red_groups Array<SpearheadGroup>
---@field private _blue_groups Array<SpearheadGroup>
---@field private _cleanup_units table<string, boolean>
---@field private _airbase Airbase?
---@field private _initialSide number?
---@field private _supplyHubs Array<SupplyHub>
---@field private _groupsPerKilo number
---@field private _requiredBuildingKilos number
---@field private _receivedBuildingKilos number
---@field private _buildableMission BuildableMission?
local StageBase = {}
StageBase.__index = StageBase

---comment
---@param databaseManager Database
---@param logger table
---@param airbaseName string
---@param spawnManager SpawnManager
---@return StageBase?
function StageBase.New(databaseManager, logger, airbaseName, spawnManager)
    setmetatable(StageBase, Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone)
    local self = setmetatable({}, StageBase)

    self._database = databaseManager
    self._logger = logger

    self._red_groups = {}
    self._blue_groups = {}
    self._cleanup_units = {}
    self._supplyHubs = {}

    self._airbase = Airbase.getByName(airbaseName)
    self._initialSide = Spearhead.DcsUtil.getStartingCoalition(self._airbase)

    do --init
        local airbaseData = databaseManager:getAirbaseDataForZone(airbaseName)
        if airbaseData == nil then
            logger:error("Airbase data not found for airbase: " .. airbaseName)
            return nil
        end

        ---@type table<string, Vec3>
        local redUnitsPos = {}

        ---@type table<string, Vec3>
        local blueUnitsPos = {}

        for _, groupName in pairs(airbaseData.RedGroups) do
            local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName, spawnManager, true)
            table.insert(self._red_groups, shGroup)

            for _, unit in pairs(shGroup:GetObjects()) do
                redUnitsPos[unit:getName()] = unit:getPoint()
            end

            shGroup:Destroy()
        end

        for _, groupName in pairs(airbaseData.BlueGroups) do
            local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName, spawnManager, true)
            table.insert(self._blue_groups, shGroup)

            for _, unit in pairs(shGroup:GetObjects()) do
                blueUnitsPos[unit:getName()] = unit:getPoint()
            end

            shGroup:Destroy()
        end

        for _, supplyHubName in pairs(airbaseData.supplyHubNames) do
            local supplyHub = Spearhead.classes.stageClasses.SpecialZones.SupplyHub.new(databaseManager, logger,
                supplyHubName)
            if supplyHub then
                table.insert(self._supplyHubs, supplyHub)
            end
        end

        do -- check cleanup requirements
            -- Checks is any of the units are withing range (5m) of another unit.
            -- If so, make sure to add them to the cleanup list.

            local cleanup_distance = 5

            for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
                for redUnitName, redUnitPos in pairs(redUnitsPos) do
                    local distance = Spearhead.Util.VectorDistance3d(blueUnitPos, redUnitPos)
                    if distance <= cleanup_distance then
                        self._cleanup_units[redUnitName] = true
                    end
                end
            end
        end

        local zone = Spearhead.DcsUtil.getAirbaseZoneByName(airbaseName)
        if zone then
            Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone.New(self, zone, airbaseData.buildingKilos or 0, "AIRBASE_CRATE", self._blue_groups, logger, databaseManager)
        end
    end

    return self
end

---@private
function StageBase:SpawnRedUnits()
    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._red_groups, timer.getTime() + 3)
end

---@private
function StageBase:CleanRedUnits()
    for _, value in pairs(self._red_groups) do
        value:SpawnCorpsesOnly()
    end

    for unitName, shouldClean in pairs(self._cleanup_units) do
        if shouldClean == true then
            Spearhead.DcsUtil.DestroyUnit(unitName)
            Spearhead.DcsUtil.CleanCorpse(unitName)
        end
    end
end

---@private
function StageBase:SpawnBlueUnits()
    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._blue_groups, timer.getTime() + 3)
end

function StageBase:ActivateRedStage()
    self._logger:debug("Activate red stage for airbase: " .. self._airbase:getName())
    if self._airbase and (self._initialSide == 2 or self._initialSide == 1) then
        self._airbase:setCoalition(coalition.side.RED)
        self._airbase:autoCapture(false)
    end
    self:SpawnRedUnits()
end

function StageBase:ActivateBlueStage()
    self._logger:debug("Activate blue stage for airbase: " .. self._airbase:getName())

    self:CleanRedUnits()

    if self._buildableMission then
        self:StartBuildable()
    else
        self:FinaliseBlueStage()
    end
    
end

function StageBase:FinaliseBlueStage()
    if self._initialSide == 2 and self._airbase then
        self._airbase:setCoalition(coalition.side.BLUE)
        self._airbase:autoCapture(false)
    end

    self:SpawnBlueUnits()

    for _, hub in pairs(self._supplyHubs) do
        hub:Activate()
    end
end


function StageBase:OnBuildingComplete()
    self:FinaliseBlueStage()
end



if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.StageBase = StageBase
