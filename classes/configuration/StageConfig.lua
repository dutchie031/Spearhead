
--- @class StageConfig
--- @field isEnabled boolean
--- @field isDrawStagesEnabled boolean
--- @field isAutoStages boolean
--- @field startingStage integer
--- @field maxMissionsPerStage integer


local StageConfig = {};

---comment
---@return StageConfig
function StageConfig:new()

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.StageConfig == nil then SpearheadConfig.StageConfig = {} end

    ---@type StageConfig
    local o = {
        isEnabled = SpearheadConfig.StageConfig.enabled or true,
        isDrawStagesEnabled = SpearheadConfig.StageConfig.drawStages or true,
        isAutoStages = SpearheadConfig.StageConfig.autoStages or true,
        startingStage = SpearheadConfig.StageConfig.startingStage or 1,
        maxMissionsPerStage = SpearheadConfig.StageConfig.maxMissionStage or 10
    }
    setmetatable(o, { __index = self })

    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.StageConfig = StageConfig;