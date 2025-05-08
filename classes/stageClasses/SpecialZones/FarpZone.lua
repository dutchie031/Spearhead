

---@class FarpZone
---@field private _startingFarp boolean
---@field private _groups Array<SpearheadGroup>
---@field private _padNames Array<string>
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
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
    self:BuildUp()
    self:SetPadsBlue()

end

function FarpZone:Deactivate()

    self:NeutralisePads()

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


if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.FarpZone = FarpZone
