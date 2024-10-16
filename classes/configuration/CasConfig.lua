

local CasConfig = {}


function CasConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CasConfig == nil then SpearheadConfig.CasConfig = {} end
    if SpearheadConfig.CapConfig == nil then SpearheadConfig.CapConfig = {} end

    local requireEscort = (SpearheadConfig.CasConfig.requireEscort == true) or false
    ---@param self table
    ---@return boolean
    CasConfig.requireEscort = function(self)
        return requireEscort == true
    end

    local minSpeed = (tonumber(SpearheadConfig.CasConfig.minSpeed) or tonumber(SpearheadConfig.CapConfig.minSpeed) or 400) * 0.514444
    ---@return number
    o.getMinSpeed = function(self) return minSpeed end

    local maxSpeed = (tonumber(SpearheadConfig.CasConfig.maxSpeed) or tonumber(SpearheadConfig.CapConfig.maxSpeed) or 400) * 0.514444
    o.getMaxSpeed = function(self) return maxSpeed end

    return o

end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CasConfig = CasConfig;