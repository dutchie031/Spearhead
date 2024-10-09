

local CapConfig = {};
function CapConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CapConfig == nil then SpearheadConfig.CapConfig = {} end

    local enabled = SpearheadConfig.CapConfig.enabled or true
    ---@return boolean
    o.isEnabled = function() return enabled == true end

    local minSpeed = tonumber(SpearheadConfig.CapConfig.minSpeed) or 400
    ---@return number
    o.getMinSpeed = function() return minSpeed end

    local maxSpeed = tonumber(SpearheadConfig.CapConfig.maxSpeed) or 400
    ---@return number
    o.getMaxSpeed = function() return maxSpeed end

    local minAlt = tonumber(SpearheadConfig.CapConfig.minAlt) or 18000
    ---@return number
    o.getMinAlt = function() return minAlt end

    local maxAlt = tonumber(SpearheadConfig.CapConfig.maxAlt) or 28000
    ---@return number
    o.getMaxAlt = function() return maxAlt end

    local rearmDelay = tonumber(SpearheadConfig.CapConfig.rearmDelay) or 600
    ---@return number
    o.getRearmDelay = function() return rearmDelay end

    local deathDelay = tonumber(SpearheadConfig.CapConfig.deathDelay) or 1800
    ---@return number
    o.getDeathDelay = function() return deathDelay end
    
    return o;
end
Spearhead.internal.configuration.CapConfig = CapConfig;