---@class SupplyHub
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _zone SpearheadTriggerZone?
---@field private _supplyUnitsTracker SupplyUnitsTracker
---@field private _isCommmandAdded table<string, boolean>
---@field private _missionCommandsHelper MissionCommandsHelper
---@field private _inZone table<string, boolean>
---@field private _drawID number
---@field private _cargoInUnits table<table<string, number>>
---@field private _activeAtStart boolean
---@field private _active boolean
local SupplyHub = {}

---@param database Database
---@param logger Logger
---@param zoneName string
---@return SupplyHub?
function SupplyHub.new(database, logger, zoneName)

    SupplyHub.__index = SupplyHub
    local self = setmetatable({}, SupplyHub)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    local split = Spearhead.Util.split_string(zoneName, "_")
    if string.lower(split[2]) == "a" then
        self._activeAtStart = true
    else
        self._activeAtStart = false
    end

    self._zone = Spearhead.DcsUtil.getZoneByName(zoneName)
    
    self._supplyUnitsTracker = Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker.getOrCreate()
    self._inZone = {}
    self._missionCommandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(logger.LogLevel)

    self._logger:debug("Creating Supply Hub zone: " .. self._zoneName)

    return self
end

function SupplyHub:IsActiveFromStart()
    return self._activeAtStart
end

function SupplyHub:GetZoneName()
    return self._zoneName
end

---@return SpearheadTriggerZone?
function SupplyHub:GetZone()
    return self._zone
end

function SupplyHub:Activate()
    if self._active == true then
        return
    end

    self._active = true

    self._logger:debug("Activating Supply Hub zone: " .. self._zoneName)

    local zone = Spearhead.DcsUtil.getZoneByName(self._zoneName)
    if zone and self._drawID == nil then
        ---@type DrawColor
        local fillColor = { r=0, g=1, b=0, a=0.2 }
        ---@type DrawColor
        local lineColor = { r=0, g=1, b=0, a=1}
        local lineStyle = 1
        self._drawID = Spearhead.DcsUtil.DrawZone(zone, lineColor, fillColor, lineStyle)
    end

    self._supplyUnitsTracker:RegisterHub(self)

end


if not Spearhead then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.SupplyHub = SupplyHub