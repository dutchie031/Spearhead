---@type Array<OnMissionCompleteListener>
local MissionCompleteListeners = {}

---@type SpearheadAPI
SpearheadAPI = {
    Stages = {
        changeStage = function(stageNumber)
            if type(stageNumber) ~= "number" then
                return false, "stageNumber " .. stageNumber .. " is not a valid number"
            end

            Spearhead.Events.PublishStageNumberChanged(stageNumber)
            return true, ""
        end,
        getCurrentStage = function()
            return Spearhead.StageNumber or nil
        end,
        isStageComplete = function(stageNumber)
            if type(stageNumber) ~= "number" then
                return false, "stageNumber " .. stageNumber .. " is not a valid number"
            end

            local isComplete = Spearhead.internal.GlobalStageManager.isStageComplete(stageNumber)
            if isComplete == nil then
                return nil, "no stage found with number " .. stageNumber
            end

            return isComplete, ""
        end
    },
    Missions = {
        addOnMissionCompleteListener = function(listener)
            if type(listener) ~= "table" or type(listener.onMissionComplete) ~= "function" then
                error("listener is not a valid OnMissionCompleteListener")
            end

            table.insert(MissionCompleteListeners, listener)
        end
    },

    --- Internal Functions for the API that can be called through the rest of the Framework
    Internal = {
        notifyMissionComplete = function(zone_name)
            for _, listener in ipairs(MissionCompleteListeners) do
                    pcall(function()
                        listener:onMissionComplete(zone_name)
                    end)
            end
        end,
    }


}
