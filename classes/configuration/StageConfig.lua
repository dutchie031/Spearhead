
local StageConfig = {};
function StageConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.StageConfig == nil then SpearheadConfig.StageConfig = {} end

    local enabled = SpearheadConfig.StageConfig.enabled or true
    ---@return boolean
    o.isEnabled = function() return enabled == true end

    o.logLevel  = Spearhead.LoggerTemplate.LogLevelOptions.INFO

    return o;
end
Spearhead.internal.configuration.StageConfig = StageConfig;