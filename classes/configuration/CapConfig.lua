

local CapConfig = {};
function CapConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CapConfig == nil then SpearheadConfig.CapConfig = {} end

    local enabled = SpearheadConfig.CapConfig.enabled
    if enabled == nil then enabled = true end
    ---@return boolean
    o.isEnabled = function(self) return enabled == true end

    local minSpeed = (tonumber(SpearheadConfig.CapConfig.minSpeed) or 400) * 0.514444
    ---@return number
    o.getMinSpeed = function(self) return minSpeed end

    local maxSpeed = (tonumber(SpearheadConfig.CapConfig.maxSpeed) or 400) * 0.514444
    ---@return number
    o.getMaxSpeed = function(self) return maxSpeed end

    local minAlt = (tonumber(SpearheadConfig.CapConfig.minAlt) or 18000) * 0.3048
    ---@return number
    o.getMinAlt = function(self) return minAlt end

    local maxAlt = (tonumber(SpearheadConfig.CapConfig.maxAlt) or 28000) * 0.3048
    ---@return number
    o.getMaxAlt = function(self) return maxAlt end

    local minDurationOnStation  = 1200
    ---@return number
    o.getMinDurationOnStation = function(self) return minDurationOnStation end

    local maxDurationOnStation = 2700
    ---@return number
    o.getmaxDurationOnStation = function(self) return maxDurationOnStation end

    local maxDeviationRange = 20 * 1852;
     ---@return number
    o.getMaxDeviationRange = function(self) return maxDeviationRange end

    local rearmDelay = tonumber(SpearheadConfig.CapConfig.rearmDelay) or 600
    ---@return number
    o.getRearmDelay = function(self) return rearmDelay end

    local deathDelay = tonumber(SpearheadConfig.CapConfig.deathDelay) or 1800
    ---@return number
    o.getDeathDelay = function(self) return deathDelay end
    o.logLevel  = "INFO"

    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CapConfig = CapConfig;