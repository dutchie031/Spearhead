
---@class BlueSam : BuildableZone
---@field Activate fun(self: BlueSam)
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _blueGroups Array<SpearheadGroup>
---@field private _cleanupUnits table<string, boolean>
---@field private _buildableCrateKilos number?
---@field private _receivedKilos number?
---@field private _unitsPerCrate number?
---@field private _buildableMission BuildableMission?
local BlueSam = {}
BlueSam.__index = BlueSam

---@param database Database
---@param logger Logger
---@param zoneName string
---@param spawnManager SpawnManager
---@return BlueSam?
function BlueSam.New(database, logger, zoneName, spawnManager)

    setmetatable(BlueSam, Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone)
    local self = setmetatable({}, BlueSam)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    self._blueGroups = {}
    self._cleanupUnits = {}

    local blueSamData = database:getBlueSamDataForZone(zoneName)

    if blueSamData == nil then
        logger:error("Blue SAM data not found for zone: " .. zoneName)
        return nil
    end

    self._buildableCrateKilos = blueSamData.buildingKilos
    self._receivedKilos = 0

    ---@type table<string, Vec3>
    local blueUnitsPos = {}

    ---@type table<string, Vec3>
    local redUnitsPos = {}

    
    local buildable = false
    if self._buildableCrateKilos and self._buildableCrateKilos > 0 then
        buildable = true
    end

    for _, groupName in pairs(blueSamData.groups) do
        local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName, spawnManager, true)
        if SpearheadGroup then
            
            if SpearheadGroup:GetCoalition() == 2 or SpearheadGroup:GetCoalition() == 0 then
                table.insert(self._blueGroups, SpearheadGroup)
            end

            for _, unit in pairs(SpearheadGroup:GetObjects()) do
                if SpearheadGroup:GetCoalition() == 1 then
                    table.insert(blueUnitsPos, unit:getPoint())
                elseif SpearheadGroup:GetCoalition() == 2 then
                    table.insert(redUnitsPos, unit:getPoint())
                end
            end

        end
        SpearheadGroup:Destroy()
    end

    --Cleanup units
    local cleanup_distance = 5
    for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
        for redUnitName, redUnitPos in pairs(redUnitsPos) do
            local distance = Spearhead.Util.VectorDistance3d(blueUnitPos, redUnitPos)
            if distance <= cleanup_distance then
                self._cleanupUnits[redUnitName] = true
            end
        end
    end

    local zone = Spearhead.DcsUtil.getZoneByName(zoneName)
    if zone then
        Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone.New(self, zone, self._buildableCrateKilos or 0, "SAM_CRATE", self._blueGroups, logger, database)
    end

    return self
end

---@private
---@return SpearheadTriggerZone?
function BlueSam:GetNoLandingZone()

    ---@type Array<Vec2>
    local points = {}

    for _, group in pairs(self._blueGroups) do
        for _, unitPos in pairs(group:GetAllUnitPositions()) do
            table.insert(points, { x = unitPos.x, y = unitPos.z })
        end
    end

    local vecs = Spearhead.Util.getConvexHull(points)

    local zone = Spearhead.DcsUtil.getZoneByName(self._zoneName)
    if zone == nil then
        self._logger:error("Zone not found: " .. self._zoneName)
        return nil
    end

    ---@type SpearheadTriggerZone
    local spearheadZone = {
        name = self._zoneName .. "_noland",
        location = zone.location,
        verts = vecs,
        radius = 0,
        zone_type = "Polygon"
    }

    return spearheadZone
end

function BlueSam:Activate()

    if self._buildableMission == nil then
        self:SpawnGroups()
    else
        self:StartBuildable()
    end

end

function BlueSam:SpawnGroups()
    for unitName, needsCleanup in pairs(self._cleanupUnits) do
        Spearhead.DcsUtil.DestroyUnit(unitName)
    end

    for _, group in pairs(self._blueGroups) do
        group:Spawn()
    end
end

function BlueSam:OnBuildingComplete()
    self:SpawnGroups()
end



if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.BlueSam = BlueSam
