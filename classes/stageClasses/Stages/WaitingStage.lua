
---@class WaitingStage : Stage
---@field private _waitTimeSeconds integer
---@field private _startTime number
local WaitingStage = {}

WaitingStage.__index = WaitingStage

---@class WaitingStageInitData : StageInitData
---@field waitingSeconds integer
local WaitingStageInitData = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData WaitingStageInitData
---@return WaitingStage
function WaitingStage.New(database, stageConfig, logger, initData)

    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(WaitingStage, Stage)

    local self = setmetatable({}, { __index = WaitingStage }) --[[@as WaitingStage]]
    self:superNew(database, stageConfig, logger, initData, "none")

    self._waitTimeSeconds = 5
    if initData.waitingSeconds and initData.waitingSeconds > 5 then self._waitTimeSeconds  = initData.waitingSeconds end
    self._startTime = nil

    self.CheckContinuousAsync = function (selfA, time)
       
        if selfA:IsComplete() == true then
            selfA:NotifyComplete()
            return nil
        end

        return time + 2
    end

    return self
end


function WaitingStage:ActivateStage()

    self._logger:info("Starting Waiting Stage '" .. self.zoneName .. "' which will complete in about " .. self._waitTimeSeconds .. " seconds")

    self._isActive = true
    self._startTime = timer.getTime()
    timer.scheduleFunction(self.CheckContinuousAsync, self, self._startTime + self._waitTimeSeconds)
end

function WaitingStage:IsComplete() 
    if timer.getTime() > (self._startTime + self._waitTimeSeconds) then return true end
    return false
end

function WaitingStage:OnStageNumberChanged()
    self._logger:debug("Waiting Stage OnStageNumberChanged override")
end

function WaitingStage:MarkStage(stageColor)
    self._logger:debug("Waiting Stage MarkStage override")
end

function WaitingStage:GetExpectedTime()
    return self._startTime + self._waitTimeSeconds    
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.WaitingStage = WaitingStage


