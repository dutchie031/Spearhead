


local SpearheadAPI = {}
do
    
    --- Changes the active stage of spearhead.
    --- All other stages will change based on the normal logic. (CAP, BLUE etc.)
    --- @param stageNumber number the stage number you want changed
    --- @return boolean success indicator of success
    --- @return string message error message
    SpearheadAPI.changeStage = function(stageNumber) 
        if type(stageNumber) ~= "number" then
            return false, "stageNumber " .. stageNumber .. " is not a valid number"
        end

        Spearhead.Events.PublishStageNumberChanged(stageNumber)
        return true, ""
    end

    ---Returns the current stange number
    ---Returns nil when the stagenumber was not set before ever, which means Spearhead was not started.
    ---@return number | nil
    SpearheadAPI.getCurrentStage = function()
        return Spearhead.StageNumber or nil
    end

end


if Spearhead == nil then Spearhead = {} end
Spearhead.API = SpearheadAPI


