

---@class PrimaryStage : Stage
local PrimaryStage = {}

local Stage = Spearhead.classes.stageClasses.Stages.__Stage

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return PrimaryStage
function PrimaryStage:New(database, stageConfig, logger, initData)
    PrimaryStage.__index = PrimaryStage
    setmetatable(PrimaryStage, { __index = Stage })

    Stage.New(self, database, stageConfig, logger, initData)
    setmetatable(self, PrimaryStage)

    return self
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.PrimaryStage = PrimaryStage


