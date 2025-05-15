

---@class FarpZone : OnCrateDroppedListener, MissionCompleteListener
---@field private _startingFarp boolean
---@field private _groups Array<SpearheadGroup>
---@field private _padNames Array<string>
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _requiredCrates number
---@field private _receivedCrates number
---@field private _buildableMission BuildableMission?
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

    if farpData then
        self._padNames = farpData.padNames

        for _, groupName in pairs(farpData.groups) do 
            local group = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
            table.insert(self._groups, group)
            group:Destroy()
        end

        self._requiredCrates = farpData.buildingCrates
        self._receivedCrates = 0

        if self._requiredCrates ~= nil and self._requiredCrates > 0 then
            self._logger:debug("FARP zone " .. zoneName .. " requires " .. self._requiredCrates .. " crates to be dropped off")
            local noLandingZone = self:GetNoLandingZone()
            self._buildableMission = Spearhead.classes.stageClasses.missions.BuildableMission.new(database, logger, zoneName, noLandingZone, self._requiredCrates, "FARP_CRATE")
            if self._buildableMission then
                self._buildableMission:AddOnCrateDroppedOfListener(self)
                self._buildableMission:AddMissionCompleteListener(self)
            end

        end

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
    else
        self._buildableMission:SpawnActive()
    end
end

function FarpZone:Deactivate()
    self:NeutralisePads()
end

---@param buildableMission BuildableMission
function FarpZone:OnCrateDroppedOff(buildableMission)

    self._logger:debug("Crate dropped off in zone: " .. self._zoneName)

    self._receivedCrates = self._receivedCrates+ 1

end

---@param buildableMission Mission
function FarpZone:OnMissionComplete(buildableMission)
    self._logger:debug("Buildable mission complete for zone: " .. self._zoneName)

    self:BuildUp()
    self:SetPadsBlue()

end

function FarpZone:BuildUp()
    for _, group in pairs(self._groups) do
        group:Spawn()
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
