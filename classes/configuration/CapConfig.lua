
---@class CapConfig
---@field private _isEnabled boolean
---@field private _minSpeed number
---@field private _maxSpeed number
---@field private _minAlt number
---@field private _maxAlt number
---@field private _minDurationOnStation number
---@field private _maxDurationOnStation number
---@field private _maxDeviationRange number
---@field private _rearmDelay number
---@field private _repairDelay number
---@field private _deathDelay number
local CapConfig = {};
CapConfig.__index = CapConfig

---@return CapConfig
function CapConfig.new()
    local o = {}
    local self = setmetatable({}, CapConfig)

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CapConfig == nil then SpearheadConfig.CapConfig = {} end

    local enabled = SpearheadConfig.CapConfig.enabled
    if enabled == nil then enabled = true end
    self._isEnabled = enabled

    self._minSpeed = (tonumber(SpearheadConfig.CapConfig.minSpeed) or 400) * 0.514444
    self._maxSpeed = (tonumber(SpearheadConfig.CapConfig.maxSpeed) or 400) * 0.514444

    self._minAlt = (tonumber(SpearheadConfig.CapConfig.minAlt) or 18000) * 0.3048
    self._maxAlt = (tonumber(SpearheadConfig.CapConfig.maxAlt) or 28000) * 0.3048

    self._minDurationOnStation = 1200
    self._maxDurationOnStation = 2700

    self._maxDeviationRange = 20 * 1852 -- 20 nautical miles in meters
    self._rearmDelay = tonumber(SpearheadConfig.CapConfig.rearmDelay) or 600
    self._repairDelay = tonumber(SpearheadConfig.CapConfig.repairDelay) or 600
    self._deathDelay = tonumber(SpearheadConfig.CapConfig.deathDelay) or 1800

    return o;
end

function CapConfig:isEnabled()
    return self._isEnabled
end

---@return number
function CapConfig:getMinSpeed()
    return self._minSpeed
end

---@return number
function CapConfig:getMaxSpeed()
    return self._maxSpeed
end

---@return number
function CapConfig:getMinAlt()
    return self._minAlt
end

---@return number
function CapConfig:getMaxAlt()
    return self._maxAlt
end

---@return number
function CapConfig:getMinDurationOnStation()
    return self._minDurationOnStation
end

---@return number
function CapConfig:getMaxDurationOnStation()
    return self._maxDurationOnStation
end

---@return number
function CapConfig:getMaxDeviationRange()
    return self._maxDeviationRange
end

---@return number
function CapConfig:getRearmDelay()
    return self._rearmDelay
end

function CapConfig:getRepairDelay()
    return self._repairDelay
end

---@return number
function CapConfig:getDeathDelay()
    return self._deathDelay
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CapConfig = CapConfig;