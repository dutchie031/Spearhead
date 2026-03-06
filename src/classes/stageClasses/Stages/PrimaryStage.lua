
---@class PrimaryStage : Stage
local PrimaryStage = {}

PrimaryStage.__index = PrimaryStage

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@param spawnManager SpawnManager
---@return PrimaryStage
function PrimaryStage.New(database, stageConfig, logger, initData, spawnManager)

    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(PrimaryStage, Stage)

    local self = setmetatable({}, { __index = PrimaryStage }) --[[@as PrimaryStage]]
    self:superNew(database, stageConfig, logger, initData, "primary", spawnManager)
    return self

end

return PrimaryStage


