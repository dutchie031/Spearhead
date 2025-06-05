

---@class FarpZone: BuildableZone 
---@field private _startingFarp boolean
---@field private _groups Array<SpearheadGroup>
---@field private _padNames Array<string>
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _supplyHubs Array<SupplyHub>
local FarpZone = {}
FarpZone.__index = FarpZone

---comment
---@param database Database
---@param logger Logger
---@param zoneName string
---@param spawnManager SpawnManager
---@return FarpZone
function FarpZone.New(database, logger, zoneName, spawnManager)
    setmetatable(FarpZone, Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone)
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
            local group = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName, spawnManager, true)
            table.insert(self._groups, group)
            group:Destroy()
        end

        local zone = Spearhead.DcsUtil.getZoneByName(zoneName)
        if zone then
            Spearhead.classes.stageClasses.SpecialZones.abstract.BuildableZone.New(self, zone, farpData.buildingKilos or 0, "FARP_CRATE",  self._groups, logger, database)
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
        self:ActivateSupplyHubs()
    else
        self:StartBuildable()
    end
end

function FarpZone:Deactivate()
    self:NeutralisePads()
end

function FarpZone:OnBuildingComplete()
    self:BuildUp()
    self:SetPadsBlue()
    self:ActivateSupplyHubs()
end

---@private
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

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.FarpZone = FarpZone
