

local MissionCommandsHelper = {}
do
    
    local missionCommands = {}
    local missions = {}

    local _isInitiated = false
    local initiateMissionCommands = function()
        if _isInitiated == true then
            return
        end
        
        missionCommands.addSubMenu("Primary Missions")
        missionCommands.addSubMenu("Secondary Missions")

        _isInitiated = true
    end


    ---Add a mission to the F10 commands menu
    ---@param mission Mission
    MissionCommandsHelper.AddMissionToCommands = function (mission)
        initiateMissionCommands()


        
    end

    local updateCommandsForGroup = function(group)

    end

    MissionCommandsHelper.UpdateCommands = function()

    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.MissionCommandsHelper = MissionCommandsHelper
