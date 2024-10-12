

local CasConfig = {}


function CasConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CasConfig == nil then SpearheadConfig.CasConfig = {} end

    local requireEscort = (SpearheadConfig.CasConfig.requireEscort == true) or false
    ---@param self table
    ---@return boolean
    CasConfig.requireEscort = function(self)
        return requireEscort == true
    end

    return o

end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CasConfig = CasConfig;