
---@class ExtraStage : Stage
local ExtraStage = {}
ExtraStage.__index = ExtraStage


---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return ExtraStage
function ExtraStage.New(database, stageConfig, logger, initData)

    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(ExtraStage, Stage)

    local self = setmetatable({}, { __index = ExtraStage }) --[[@as ExtraStage]]
    self:superNew(database, stageConfig, logger, initData, "secondary")

    self.OnPostBlueActivated = function (selfStage)
        
        selfStage:MarkStage(Stage.StageColors.GRAY)
    end
    
    self.OnPostStageComplete = function (selfStage)
        selfStage:ActivateBlueStage()
    end

    return self
end

---comment
---@param self Stage
---@param number integer
function ExtraStage:OnStageNumberChanged(number)

    self._activeStage = number
    if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
        self:PreActivate(false)
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


