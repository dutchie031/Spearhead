---@class StageBase : OnCrateDroppedListener, MissionCompleteListener
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

---comment
---@param databaseManager Database
---@param logger table
---@param airbaseName string
---@return StageBase?
function StageBase.New(databaseManager, logger, airbaseName)
    StageBase.__index = StageBase
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
            local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
            table.insert(self._red_groups, shGroup)

            for _, unit in pairs(shGroup:GetObjects()) do
                redUnitsPos[unit:getName()] = unit:getPoint()
            end

            shGroup:Destroy()
        end

        for _, groupName in pairs(airbaseData.BlueGroups) do
            local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
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

        if airbaseData.buildingKilos ~= nil and airbaseData.buildingKilos > 0 then
            self._logger:debug("Airbase " .. airbaseName .. " requires " .. tostring(airbaseData.buildingKilos) .. " kilos to be dropped off")
            self._requiredBuildingKilos = airbaseData.buildingKilos
            self._receivedBuildingKilos = 0
            self._groupsPerKilo = Spearhead.Util.tableLength(self._blue_groups) / self._requiredBuildingKilos
            local zone = Spearhead.DcsUtil.getAirbaseZoneByName(airbaseName)
            if zone then
                self._buildableMission = Spearhead.classes.stageClasses.missions.BuildableMission.new(databaseManager, logger, zone, self:GetNoLandingZone(), self._requiredBuildingKilos, "AIRBASE_CRATE")
            end

                
            if self._buildableMission then
                self._buildableMission:AddOnCrateDroppedOfListener(self)
            else
                self._logger:error("Failed to create buildable mission for airbase: " .. airbaseName)
            end
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

    if self._buildableMission and self._buildableMission:getState() ~= "COMPLETED" then
        self._buildableMission:SpawnActive()
        return
    end
    self:FinaliseBlueStage()
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

do ---Building parts
    ---@class UnpackAirbaseCrateParam
    ---@field self StageBase
    ---@field kilos number
    ---@field groupsPerKilo number
    ---@field kilosPerSecond number
    ---@field unpackedItems number
    ---@field unpackedKilos number

    ---@param params UnpackAirbaseCrateParam
    ---@param time number
    local startUnpackingCrate = function(params, time)
        local unpacked = params.unpackedKilos + (params.kilosPerSecond * 2)
        local alreadySpawned = params.unpackedItems / params.groupsPerKilo
        local diff = unpacked - alreadySpawned

        local amount = math.floor(diff * params.groupsPerKilo)
        local spawned = params.self:SpawnAmount(amount)

        params.unpackedItems = params.unpackedItems + amount
        params.unpackedKilos = unpacked
        if params.unpackedKilos >= params.kilos or spawned == false then
            params.self:FinaliseCrate(params.kilos)
            return
        end

        return time + 2
    end

    ---comment
    ---@param amount number
    ---@return boolean
    function StageBase:SpawnAmount(amount)
        local function spawnOne()
            for _, group in pairs(self._blue_groups) do
                if group:IsSpawned() == false then
                    group:Spawn()
                    return true
                end
            end
            return nil
        end

        for i = 1, amount do
            local spawned = spawnOne()
            if spawned ~= true then
                self._logger:debug("No more groups to spawn at base: " .. self._airbase:getName())
                return false
            end
        end

        return true
    end

    ---@param buildableMission BuildableMission
    function StageBase:OnCrateDroppedOff(buildableMission, kilos)
        self._logger:debug("Crate dropped off at base: " .. self._airbase:getName())

        local timeToUnpack = (kilos / 500) * 30

        ---@type UnpackAirbaseCrateParam
        local params = {
            self = self,
            groupsPerKilo = self._groupsPerKilo,
            unpackedItems = 0,
            kilosPerSecond = kilos / timeToUnpack,
            unpackedKilos = 0,
            kilos = kilos
        }

        timer.scheduleFunction(startUnpackingCrate, params, timer.getTime() + 2)
    end

    ---@private
    ---@return SpearheadTriggerZone?
    function StageBase:GetNoLandingZone()
        ---@type Array<Vec2>
        local points = {}

        for _, group in pairs(self._blue_groups) do
            for _, unitPos in pairs(group:GetAllUnitPositions()) do
                table.insert(points, { x = unitPos.x, y = unitPos.z })
            end
        end

        local vecs = Spearhead.Util.getConvexHull(points)

        local pos = self._airbase:getPoint()
        local location = {
            x = pos.x,
            y = pos.z
        }

        ---@type SpearheadTriggerZone
        local spearheadZone = {
            name = self._airbase:getName() .. "_noland",
            location = location,
            verts = vecs,
            radius = 0,
            zone_type = "Polygon"
        }

        return spearheadZone
    end

    
    ---@param kilos number
    function StageBase:FinaliseCrate(kilos)
        self._receivedBuildingKilos = self._receivedBuildingKilos + kilos
        if self._receivedBuildingKilos >= self._requiredBuildingKilos then
            self:FinaliseBlueStage()
        end
    end
end



if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.StageBase = StageBase
