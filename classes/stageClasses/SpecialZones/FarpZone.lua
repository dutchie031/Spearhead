

---@class FarpZone
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
local FarpZone = {}
FarpZone.__index = FarpZone

---comment
---@param database Database
---@param logger Logger
---@param zoneName string
function FarpZone.New(database, logger, zoneName)
    
    FarpZone.__index = FarpZone
    local self = setmetatable({}, FarpZone)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    

end

function FarpZone:Activate()

end

function FarpZone:Deactivate()

end

---@private
function FarpZone:NeutralisePads()

end

function FarpZone:SetPadsBlue()

end