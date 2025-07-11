
---@class BuildableZone : OnCrateDroppedListener
---@field protected _targetZone SpearheadTriggerZone
---@field protected _requiredKilos number
---@field protected _buildableMission BuildableMission?
---@field protected _buildableGroups Array<SpearheadGroup>
---@field private _groupsPerKilo number
---@field private _receivedBuildingKilos number
---@field private _buildableLogger Logger
---@field protected OnBuildingComplete fun(self:BuildableZone)
local BuildableZone = {}
BuildableZone.__index = BuildableZone

---@param targetZone SpearheadTriggerZone
---@param kilosRequired number
---@param buildableGroups Array<SpearheadGroup>
---@param database Database
---@param crateType SupplyType
---@param logger Logger
function BuildableZone:New(targetZone, kilosRequired, crateType,  buildableGroups, logger, database)
    self._targetZone = targetZone
    self._requiredKilos = kilosRequired or 0
    self._buildableGroups = buildableGroups or {}
    self._buildableLogger = logger
    local totalGroups = Spearhead.Util.tableLength(self._buildableGroups)
    self._groupsPerKilo = totalGroups / self._requiredKilos

    self._receivedBuildingKilos = 0
    local persistedKilos = Spearhead.classes.persistence.Persistence.GetZoneDeliveredKilos(targetZone.name)
    if persistedKilos and persistedKilos > 0 then
        self._receivedBuildingKilos = persistedKilos

        ---@param params UnpackCrateParam
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
                return
            end
        
            return time + 0.5
        end

        ---@type UnpackCrateParam
        local params = {
            self = self,
            groupsPerKilo = self._groupsPerKilo,
            unpackedItems = 0,
            kilosPerSecond = persistedKilos/30,
            unpackedKilos = 0,
            kilos = persistedKilos
        }

        timer.scheduleFunction(startUnpackingCrate, params, timer.getTime() + 5)
        kilosRequired = kilosRequired - persistedKilos
    end

    local noLandingZone = self:GetNoLandingZone()
    if kilosRequired and kilosRequired > 0 then
        self._buildableMission = Spearhead.classes.stageClasses.missions.BuildableMission.new(database, logger, targetZone, noLandingZone, kilosRequired, crateType)
        self._buildableMission:AddOnCrateDroppedOfListener(self)
    else
        self._buildableMission = nil
    end


    
    if self._buildableMission == nil then
        self._buildableLogger:debug("No buildable mission for zone: " .. targetZone.name)
    end
end

---@protected
function BuildableZone:StartBuildable()
    self._buildableMission:SpawnActive()
end

---@protected 
function BuildableZone:OnBuildingComplete() end

---@class UnpackCrateParam
---@field self BuildableZone
---@field kilos number
---@field groupsPerKilo number
---@field kilosPerSecond number
---@field unpackedItems number
---@field unpackedKilos number

---@param mission BuildableMission?
---@param kilos number
function BuildableZone:OnCrateDroppedOff(mission, kilos)
    self._buildableLogger:debug("Crate dropped off in zone: " .. self._targetZone.name)

    local timeToUnpack = (kilos / 500) * 15

    ---@type UnpackCrateParam
    local params = {
        self = self,
        groupsPerKilo = self._groupsPerKilo,
        unpackedItems = 0,
        kilosPerSecond = kilos/timeToUnpack,
        unpackedKilos = 0,
        kilos = kilos
    }

    ---@param params UnpackCrateParam
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

    timer.scheduleFunction(startUnpackingCrate, params, timer.getTime() + 2)
end

---@param kilos number
function BuildableZone:FinaliseCrate(kilos)
    self._receivedBuildingKilos = self._receivedBuildingKilos + kilos
    Spearhead.classes.persistence.Persistence.SetZoneDeliveredKilos(self._targetZone.name, self._receivedBuildingKilos)
    if self._receivedBuildingKilos >= self._requiredKilos then
        self:OnBuildingComplete()
    end
end

---@private 
---@return SpearheadTriggerZone?
function BuildableZone:GetNoLandingZone()

    ---@type Array<Vec2>
    local points = {}

    for _, group in pairs(self._buildableGroups) do
        for _, unitPos in pairs(group:GetAllUnitPositions()) do
            table.insert(points, { x = unitPos.x, y = unitPos.z })
        end
    end

    local vecs = Spearhead.Util.getConvexHull(points)

    ---@type SpearheadTriggerZone
    local spearheadZone = {
        name = self._targetZone.name .. "_noland",
        location = self._targetZone.location,
        verts = vecs,
        radius = 0,
        zone_type = "Polygon"
    }

    return spearheadZone
end


---comment
---@param amount number
---@return boolean
function BuildableZone:SpawnAmount(amount)
    local function spawnOne()
        for _, group in pairs(self._buildableGroups) do
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
            self._buildableLogger:debug("No more groups to spawn in zone: " .. self._targetZone.name)
            return false
        end
    end

    return true
end

if not Spearhead then Spearhead = {} end
Spearhead.classes = Spearhead.classes or {}
Spearhead.classes.stageClasses = Spearhead.classes.stageClasses or {}
Spearhead.classes.stageClasses.SpecialZones = Spearhead.classes.stageClasses.SpecialZones or {}
Spearhead.classes.stageClasses.SpecialZones.abstract = Spearhead.classes.stageClasses.SpecialZones.abstract or {}
Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone = BuildableZone