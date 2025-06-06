

---@class FarpZone : OnCrateDroppedListener, MissionCompleteListener
---@field private _startingFarp boolean
---@field private _groups Array<SpearheadGroup>
---@field private _padNames Array<string>
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _requiredBuildingKilos number
---@field private _receivedBuildingKilos number
---@field private _groupsPerKilo number
---@field private _buildableMission BuildableMission?
---@field private _supplyHubs Array<SupplyHub>
local FarpZone = {}
FarpZone.__index = FarpZone

---comment
---@param database Database
---@param logger Logger
---@param zoneName string
---@return FarpZone
function FarpZone.New(database, logger, zoneName)
    
    FarpZone.__index = FarpZone
    local self = setmetatable({}, FarpZone)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    local split = Spearhead.Util.split_string(zoneName, "_")
    if string.lower(split[2]) == "a" then
        self._startingFarp = true
    else
        self._startingFarp = false
    end

    logger:debug("FARP zone name: " .. zoneName .. " startingFarp" .. tostring(self._startingFarp))

    local farpData = database:getFarpDataForZone(zoneName)
    self._groups = {}
    self._padNames = {}
    self._supplyHubs = {}
    

    if farpData then
        self._padNames = farpData.padNames
        
        for _, supplyHubName in pairs(farpData.supplyHubNames) do
            local supplyHub = Spearhead.classes.stageClasses.SpecialZones.SupplyHub.new(database, logger, supplyHubName)
            if supplyHub then
                table.insert(self._supplyHubs, supplyHub)
            end
        end

        for _, groupName in pairs(farpData.groups) do 
            local group = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
            table.insert(self._groups, group)
            group:Destroy()
        end

        self._requiredBuildingKilos = farpData.buildingKilos
        self._receivedBuildingKilos = 0

        if self._requiredBuildingKilos ~= nil and self._requiredBuildingKilos > 0 then
            self._logger:debug("FARP zone " .. zoneName .. " requires " .. self._requiredBuildingKilos .. " crates to be dropped off")
            local noLandingZone = self:GetNoLandingZone()
            local zone = Spearhead.DcsUtil.getZoneByName(zoneName)
            if zone then
                self._buildableMission = Spearhead.classes.stageClasses.missions.BuildableMission.new(database, logger, zone, noLandingZone, self._requiredBuildingKilos, "FARP_CRATE")
                if self._buildableMission then
                    self._buildableMission:AddOnCrateDroppedOfListener(self)
                    self._buildableMission:AddMissionCompleteListener(self)
                end

                local totalGroups = Spearhead.Util.tableLength(self._groups)
                self._groupsPerKilo = totalGroups / self._requiredBuildingKilos
            end
        end
    end
    if self._buildableMission == nil then
        self._logger:debug("No buildable mission for zone: " .. zoneName)
    end
    self:Deactivate()

    return self
end


---@return boolean
function FarpZone:IsStartingFarp()
    return self._startingFarp
end

function FarpZone:Activate()
    self._logger:info("Activating FARP zone: " .. self._zoneName)

    if self._buildableMission == nil then
        self:BuildUp()
        self:SetPadsBlue()
        self:ActivateSupplyHubs()
    else
        self._buildableMission:SpawnActive()
    end
end

function FarpZone:Deactivate()
    self:NeutralisePads()
end

---@class UnpackCrateParam
---@field self FarpZone
---@field kilos number
---@field groupsPerKilo number
---@field kilosPerSecond number
---@field unpackedItems number
---@field unpackedKilos number

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

---comment
---@param amount number
---@return boolean
function FarpZone:SpawnAmount(amount)

    local function spawnOne()
        for _, group in pairs(self._groups) do
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
            self._logger:debug("No more groups to spawn in zone: " .. self._zoneName)
            return false
        end
    end

    return true
end

---@param buildableMission BuildableMission
function FarpZone:OnCrateDroppedOff(buildableMission, kilos)

    self._logger:debug("Crate dropped off in zone: " .. self._zoneName)

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

    timer.scheduleFunction(startUnpackingCrate, params, timer.getTime() + 2)

end

---@param kilos number
function FarpZone:FinaliseCrate(kilos)
    self._receivedBuildingKilos = self._receivedBuildingKilos + kilos
    if self._receivedBuildingKilos >= self._requiredBuildingKilos then
        self:BuildUp()
        self:SetPadsBlue()
        self:ActivateSupplyHubs()
    end
end

---@param buildableMission Mission
function FarpZone:OnMissionComplete(buildableMission)
    self._logger:debug("Buildable mission complete for zone: " .. self._zoneName)

    -- self:BuildUp()
    -- self:SetPadsBlue()
    -- self:ActivateSupplyHubs()

end

function FarpZone:BuildUp()
    for _, group in pairs(self._groups) do
        group:Spawn()
    end
end


function FarpZone:ActivateSupplyHubs()
    for _, supplyHub in pairs(self._supplyHubs) do
        supplyHub:Activate()
    end
end

---@private
function FarpZone:NeutralisePads()
    for _, name in pairs(self._padNames) do
        local base = Airbase.getByName(name)
        if base then
            base:autoCapture(false) -- Disable auto capture
            base:setCoalition(1) -- 1 = Red (Can't neutralise)
        end
    end
end

---@private
function FarpZone:SetPadsBlue()
    for _, name in pairs(self._padNames) do
        local base = Airbase.getByName(name)
        if base then
            base:autoCapture(false) -- Disable auto capture
            base:setCoalition(2) -- 2 = Blue
        end
    end
end


---@private 
---@return SpearheadTriggerZone?
function FarpZone:GetNoLandingZone()

    ---@type Array<Vec2>
    local points = {}

    for _, group in pairs(self._groups) do
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

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.FarpZone = FarpZone
