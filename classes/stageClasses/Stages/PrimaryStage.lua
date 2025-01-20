
---@class PrimaryStage : Stage
local PrimaryStage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return PrimaryStage
function PrimaryStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.__Stage
    setmetatable(PrimaryStage, Stage)
    PrimaryStage.__index = PrimaryStage
    setmetatable(PrimaryStage, {__index = Stage}) 
    
    local o = Stage.New(database, stageConfig, logger, initData, "primary") --[[@as PrimaryStage]]
    return o 
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.PrimaryStage = PrimaryStage


