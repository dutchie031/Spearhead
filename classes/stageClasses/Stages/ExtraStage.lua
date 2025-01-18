
---@class ExtraStage : Stage
local ExtraStage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return PrimaryStage
function ExtraStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.__Stage
    setmetatable(ExtraStage, Stage)

    ExtraStage.__index = ExtraStage
    local o = Stage.New({}, database, stageConfig, logger, initData, "secondary")
    setmetatable(o, ExtraStage)
    return o
end

function ExtraStage:ActivateBlueStage()
    Spearhead.classes.stageClasses.Stages.__Stage.ActivateBlueStage(self)

    pcall(function()
        self:MarkStage("GRAY")
    end)
end


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.ExtraStage = ExtraStage


