
---@class CapConfig
---@field private _isEnabled boolean
---@field private _minSpeed number
---@field private _maxSpeed number
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

    -- local minAlt = (tonumber(SpearheadConfig.CapConfig.minAlt) or 18000) * 0.3048
    -- ---@return number
    -- o.getMinAlt = function(self) return minAlt end

    -- local maxAlt = (tonumber(SpearheadConfig.CapConfig.maxAlt) or 28000) * 0.3048
    -- ---@return number
    -- o.getMaxAlt = function(self) return maxAlt end

    -- local minDurationOnStation  = 1200
    -- ---@return number
    -- o.getMinDurationOnStation = function(self) return minDurationOnStation end

    -- local maxDurationOnStation = 2700
    -- ---@return number
    -- o.getmaxDurationOnStation = function(self) return maxDurationOnStation end

    -- local maxDeviationRange = 20 * 1852;
    --  ---@return number
    -- o.getMaxDeviationRange = function(self) return maxDeviationRange end

    -- local rearmDelay = tonumber(SpearheadConfig.CapConfig.rearmDelay) or 600
    -- ---@return number
    -- o.getRearmDelay = function(self) return rearmDelay end

    -- local deathDelay = tonumber(SpearheadConfig.CapConfig.deathDelay) or 1800
    -- ---@return number
    -- o.getDeathDelay = function(self) return deathDelay end
    -- o.logLevel  = "INFO"

    return o;
end

function CapConfig:isEnabled()
    return self._isEnabled
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CapConfig = CapConfig;