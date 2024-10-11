
local StageConfig = {};
function StageConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.StageConfig == nil then SpearheadConfig.StageConfig = {} end

    local enabled = SpearheadConfig.StageConfig.enabled or true
    ---@return boolean
    o.isEnabled = function(self) return enabled == true end

    local drawStages = SpearheadConfig.StageConfig.drawStages or true
    ---@return boolean
    o.isDrawStagesEnabled = function(self) return drawStages == true end

    local autoStages = SpearheadConfig.StageConfig.autoStages or true
    ---@return boolean
    o.isAutoStages = function(self) return autoStages end

    local maxMissionsPerStage = SpearheadConfig.StageConfig.maxMissionStage
    o.getMaxMissionPerStage = function(self) return maxMissionsPerStage end

    o.logLevel  = Spearhead.LoggerTemplate.LogLevelOptions.INFO
    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.configuration.StageConfig = StageConfig;