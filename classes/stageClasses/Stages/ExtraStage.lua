
---@class ExtraStage : Stage
local ExtraStage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return ExtraStage
function ExtraStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(ExtraStage, Stage)

    ExtraStage.__index = ExtraStage
    local self = Stage.New(database, stageConfig, logger, initData, "secondary") --[[@as ExtraStage]]
    setmetatable(self, ExtraStage)

    self.OnPostBlueActivated = function (selfStage)
        selfStage:MarkStage("GRAY")
    end
    
    self.OnPostStageComplete = function (selfStage)
        self:ActivateBlueStage()
    end

    return self
end

---comment
---@param self Stage
---@param number integer
function ExtraStage:OnStageNumberChanged(number)

    self._activeStage = number
    if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
        self:PreActivate()
    end

    if number == self.stageNumber then
        self:ActivateStage()
    end

    if self._isComplete == true then
        self:ActivateBlueStage()
    end

end


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.ExtraStage = ExtraStage


