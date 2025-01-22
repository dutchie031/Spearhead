
local MissionCommandsHelper = {}
do
    ---@type table<string, Mission>
    local missionsByCode = {}

    ---@type table<string, boolean>
    local enabledByCode = {}

    local updateNeeded = false

    ---Add a mission to the F10 commands menu
    ---@param mission Mission
    MissionCommandsHelper.AddMissionToCommands = function (mission)
        missionsByCode[tostring(mission.code)] = mission
        enabledByCode[tostring(mission.code)] = true
        updateNeeded = true
    end

    ---Removes a mission from the F10 commands menu
    ---@param mission Mission
    MissionCommandsHelper.RemoveMissionToCommands = function (mission)
        enabledByCode[tostring(mission.code)] = false
        updateNeeded = true
    end

    local folderNames = {
        primary = "Primary Missions",
        secondary = "Secondary Missions"
    }

    ---Add Base Folder
    ---@param groupId integer
    local addMissionFolders = function(groupId)
        missionCommands.addSubMenuForGroup(groupId, folderNames.primary)
        missionCommands.addSubMenuForGroup(groupId, folderNames.secondary)
    end

    ---Add Mission Folder
    ---@param groupId integer
    local removeMissionFolders = function(groupId)
        missionCommands.removeItemForGroup(groupId , { folderNames.primary } )
        missionCommands.removeItemForGroup(groupId , { folderNames.secondary } )
    end

    local missionBriefingRequested = function(args)
        ---@type Mission
        local mission = args.mission
        local groupID = args.groupId

        mission:ShowBriefing(groupID)
    end

    ---comment
    ---@param groupId integer
    ---@param mission Mission
    local addMissionCommands = function(groupId, mission)

        local path = nil

        if mission.priority == "primary" then
            path = { [1] = folderNames.primary }
        elseif mission.priority == "secondary" then
            path = { [1] = folderNames.secondary }
        end

        if path then
            local missionFolderName = "[" .. mission.code .. "]" .. mission.name
            missionCommands.addSubMenuForGroup(groupId, missionFolderName, path)
            table.insert(path, missionFolderName)
            missionCommands.addCommandForGroup(groupId, "Briefing" , path , missionBriefingRequested, { groupId = groupId, mission = mission })
        end
    end

    local updateCommandsForGroup = function(group)
        local groupID = group:getID()

        -- Cleanup mission folder
        removeMissionFolders(groupID)

        -- Add mission folders
        addMissionFolders(groupID)

        for code, enabled in pairs(enabledByCode) do
            if enabled == true then
                local mission = missionsByCode[code]
                if mission then
                    addMissionCommands(groupID, mission)
                end
            end
        end
    end

    local UpdateContinuous = function(none, time)
        if updateNeeded == false then
            return time + 15
        end

        for _, unit in pairs(Spearhead.DcsUtil.getAllPlayerUnits()) do
            if unit and unit:isExist() then
                local group = unit:getGroup()
                if group then
                    updateCommandsForGroup(group)
                end
            end
        end

        updateNeeded = false
        return time + 15
    end

    timer.scheduleFunction(UpdateContinuous, {}, timer.getTime() + 10)

    do -- Player enter unit listener
        local onPlayerEnterUnit = function(unit)
            if unit then
                local group = unit:getGroup()
                if group then updateCommandsForGroup(group) end
            end
        end

        local OnPlayerEnterUnitListener = {
            OnPlayerEntersUnit = function (self, unit)
                onPlayerEnterUnit(unit)
            end,
        }
        Spearhead.Events.AddOnPlayerEnterUnitListener(OnPlayerEnterUnitListener)
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.MissionCommandsHelper = MissionCommandsHelper
