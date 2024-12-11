
local StageConfig = {};
function StageConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.StageConfig == nil then SpearheadConfig.StageConfig = {} end

    local enabled = SpearheadConfig.StageConfig.enabled
    if enabled == nil then enabled = true end
    ---@return boolean
    o.isEnabled = function(self) return enabled == true end

    local drawStages = SpearheadConfig.StageConfig.drawStages
    if drawStages == nil then drawStages = true end
    ---@return boolean
    o.isDrawStagesEnabled = function(self) return drawStages == true end

    local autoStages = SpearheadConfig.StageConfig.autoStages or true
    if autoStages == nil then autoStages = true end
    ---@return boolean
    o.isAutoStages = function(self) return autoStages end

    local maxMissionsPerStage = SpearheadConfig.StageConfig.maxMissionStage
    o.getMaxMissionsPerStage = function(self) return maxMissionsPerStage end

    o.logLevel  = Spearhead.LoggerTemplate.LogLevelOptions.INFO

    local startingStage = SpearheadConfig.StageConfig.startingStage or 1
    o.getStartingStage = function(self) return startingStage end

    o.toString = function()
        return Spearhead.Util.toString({
            maxMissionsPerStage = maxMissionsPerStage,
            enabled = enabled, 
            drawStages = drawStages,
            autoStages = autoStages
        })
    end

    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.StageConfig = StageConfig;