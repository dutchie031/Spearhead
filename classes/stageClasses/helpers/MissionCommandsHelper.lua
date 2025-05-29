
---@class MissionCommandsHelper
---@field missionsByCode table<string, Mission> @table of missions by their code
---@field enabledByCode table<string, boolean> @table of enabled missions by their code
---@field updateNeeded boolean @flag to indicate if an update is needed
---@field lastUpdate number @last update time
---@field updateContinuous fun(self: MissionCommandsHelper, time: number): number @function to update commands continuously
---@field pinnedByGroup table<string, Mission> @table of pinned missions by group ID
---@field private _supplyHubGroups table<string, boolean> @table of supply hub groups by their ID
---@field private _logger Logger @logger instance for logging
---@field private _supplyUnitsTracker SupplyUnitsTracker @supply units tracker instance
local MissionCommandsHelper = {}
MissionCommandsHelper.__index = MissionCommandsHelper

local id = 0

local instance = nil

---@return MissionCommandsHelper
---@param logLevel string @log level for the logger
function MissionCommandsHelper.getOrCreate(logLevel)
    if instance == nil then
        instance = setmetatable({}, MissionCommandsHelper)

        instance._logger = Spearhead.LoggerTemplate.new("MissionCommandsHelper", logLevel)

        instance._logger:info("Creating MissionCommandsHelper instance")

        instance.missionsByCode = {}
        instance.enabledByCode = {}
        instance.updateNeeded = false
        instance.pinnedByGroup = {}
        instance.lastUpdate = 0
        instance._supplyHubGroups = {}

        instance._supplyUnitsTracker = Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker.getOrCreate(logLevel)

        ---comment
        ---@param selfA MissionCommandsHelper
        ---@param time number
        ---@return number
        instance.updateContinuous = function(selfA, time)
            if selfA.updateNeeded == false then
                return time + 10
            end

            for _, unit in pairs(Spearhead.DcsUtil.getAllPlayerUnits()) do
                if unit and unit:isExist() then
                    local group = unit:getGroup()
                    if group then
                        selfA:updateCommandsForGroup(group:getID())
                    end
                end
            end

            selfA.lastUpdate = timer.getTime()
            selfA.updateNeeded = false
            return time + 10
        end

        timer.scheduleFunction(instance.updateContinuous, instance, timer.getTime() + 5)
        Spearhead.Events.AddOnPlayerEnterUnitListener(instance)

    end

    return instance
end

---@param mission Mission
function MissionCommandsHelper:AddMissionToCommands(mission)
    self._logger:debug("Adding mission to commands: [" .. mission.code .. "]" .. mission.name)
    self.missionsByCode[tostring(mission.code)] = mission
    self.enabledByCode[tostring(mission.code)] = true
    self.updateNeeded = true
end

---Removes a mission from the F10 commands menu
---@param mission Mission
function MissionCommandsHelper:RemoveMissionToCommands(mission)
    self.enabledByCode[tostring(mission.code)] = false
    self.updateNeeded = true
end

---@param groupID number
function MissionCommandsHelper:MarkUnitInSupplyHub(groupID)
    self._logger:debug("Marking unit in supply hub: " .. tostring(groupID))
    local updateNeeded = false
    if self._supplyHubGroups[tostring(groupID)] ~= true then
        updateNeeded = true
    end

    self._supplyHubGroups[tostring(groupID)] = true
    if updateNeeded == true then self:updateCommandsForGroup(groupID) end
end


---@param groupID number
function MissionCommandsHelper:MarkUnitOutsideSupplyHub(groupID)
    self._logger:debug("Marking unit outide supply hub: " .. tostring(groupID))
    local updateNeeded = false
    if self._supplyHubGroups[tostring(groupID)] == true then
        updateNeeded = true
    end

    self._supplyHubGroups[tostring(groupID)] = false
    if updateNeeded == true then self:updateCommandsForGroup(groupID) end
end



---@param unit Unit
function MissionCommandsHelper:OnPlayerEntersUnit(unit)
    if unit then
        local group = unit:getGroup()
        if group then self:updateCommandsForGroup(group:getID()) end
    end
end

---@class MissionBriefingRequestedArgs
---@field mission Mission @the mission object
---@field groupId integer @the group ID of the player requesting the briefing

---comment
---@param args MissionBriefingRequestedArgs
local missionBriefingRequested = function(args)
    ---@type Mission
    local mission = args.mission
    local groupID = args.groupId

    mission:ShowBriefing(groupID)
end

---@class MarkRequestedArgs
---@field mission Mission @the mission object
---@field groupId integer @the group ID of the player requesting the briefing

---@param args MarkRequestedArgs
local markRequested = function(args)

    local mission = args.mission
    if not mission then return end

    if mission.missionType == "LOGISTICS" then
        mission:MarkMissionAreaToGroup(args.groupId)
    end
end



---@class PinMissionCommandArgs
---@field self MissionCommandsHelper @the MissionCommandsHelper instance
---@field groupId integer @the group ID of the player requesting the briefing
---@field mission Mission @the mission object

local pinMissionCommand = function(args)
    ---@type MissionCommandsHelper
    local self = args.self
    local groupID = args.groupId
    local mission = args.mission

    if mission then
        self:PinMission(mission, groupID)
    end
end

---@private
function MissionCommandsHelper:AddOverviewCommand(groupID)

    local MissionsOverviewToGroup = function (id)
        
        local text = "Missions Overview\n\n"

        local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(id)

        ---comment
        ---@param mission Mission
        ---@return string
        local function formatLine(mission)

            local distanceText = "?"
            if group then
                local lead = group:getUnit(1)
                if lead and lead:isExist() == true then
                    local pos = lead:getPoint()
                    local Vec2Pos = { x= pos.x, y=pos.z }
                    local distance = Spearhead.Util.VectorDistance2d(Vec2Pos, mission.location) / 1852
                    distanceText = string.format("~%d", math.floor(distance))
                end
            end

            return string.format("[%s]\t%s \t%s \t%s %% \t%s nM\n", mission.code,  mission.missionTypeDisplay, mission.name, mission:PercentageComplete(), distanceText)
        end

        ---Primary missions
        text = text .. "Primary Missions\n"
        for code, enabled in pairs(self.enabledByCode) do
            
            if enabled == true then
                local mission = self.missionsByCode[code]
                if mission and mission:getState() == "ACTIVE" and mission.priority == "primary" then
                    text = text .. formatLine(mission)
                end
            end
        end

        ---Secondary missions
        text = text .. "\nSecondary Missions\n"
        for code, enabled in pairs(self.enabledByCode) do
            
            if enabled == true then
                local mission = self.missionsByCode[code]
                if mission and mission:getState() == "ACTIVE" and mission.priority == "secondary" then
                    text = text .. formatLine(mission)
                end
            end
        end
        
        trigger.action.outTextForGroup(id, text, 20, true)
    end

    missionCommands.removeItemForGroup(groupID, { "Overview" } )
    missionCommands.addCommandForGroup(groupID, "Overview", nil, MissionsOverviewToGroup, groupID)
end

---@private
---@param groupID number
function MissionCommandsHelper:AddPinnedMission(groupID)

    local pinndedMission = self.pinnedByGroup[tostring(groupID)]
    missionCommands.removeItemForGroup(groupID, { "Pinned Mission" })

    if pinndedMission and self.enabledByCode[tostring(pinndedMission.code)] == true then
        missionCommands.addCommandForGroup(groupID, "Pinned Mission", nil,  missionBriefingRequested, { groupId = groupID, mission = pinndedMission })
    end

end

---@param groupID number
function MissionCommandsHelper:updateCommandsForGroup(groupID)

    self._logger:debug("Updating commands for group: " .. tostring(groupID))

    self:AddPinnedMission(groupID)
    self:AddOverviewCommand(groupID)

    self:ResetFolders(groupID)

    for code, enabled in pairs(self.enabledByCode) do
        if enabled == true then
            local mission = self.missionsByCode[code]
            if mission then
                self:addMissionCommands(groupID, mission)
            end
        end
    end

    self:AddSupplyHubCommandsIfApplicable(groupID)
    self:AddCargoCommands(groupID)

    ---@param id number
    local clearView = function(id)
        trigger.action.outTextForGroup(id, "clearing...", 1, true)
    end

    missionCommands.removeItemForGroup(groupID, { "Clear View" } )
    missionCommands.addCommandForGroup(groupID, "Clear View", nil, clearView, groupID)

end

local folderNames = {
    primary = "Primary Missions",
    secondary = "Secondary Missions",
    supplyHub = "Supply Hub",
    cargo = "Cargo"
}


function MissionCommandsHelper:PinMission(mission, groupID)
    self._logger:debug("Pinning mission: [" .. mission.code .. "]" .. mission.name)
    self.pinnedByGroup[tostring(groupID)] = mission
    trigger.action.outTextForGroup(groupID, "Pinned mission: [" .. mission.code .. "]" .. mission.name, 3, true)

    self:updateCommandsForGroup(groupID)
end

---comment
---@private
---@param groupId integer
---@param mission Mission
function MissionCommandsHelper:addMissionCommands(groupId, mission)
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

        ---@type MissionBriefingRequestedArgs
        local missionBriefingRequestedArgs = { groupId = groupId, mission = mission }
        missionCommands.addCommandForGroup(groupId, "Briefing", path, missionBriefingRequested,missionBriefingRequestedArgs)

        ---@type PinMissionCommandArgs
        local pinMissionCommandArgs = { self = self, groupId = groupId, mission = mission }
        missionCommands.addCommandForGroup(groupId, "Pin", path, pinMissionCommand, pinMissionCommandArgs)

        if mission.missionType == "LOGISTICS" then
            ---@type MarkRequestedArgs
            local markRequestArgs = { groupId = groupId, mission = mission }
            missionCommands.addCommandForGroup(groupId, "Mark", path, markRequested, markRequestArgs)
        end

    end
end

---@private
---@param groupID integer
function MissionCommandsHelper:AddSupplyHubCommandsIfApplicable(groupID)

    if  self._supplyHubGroups[tostring(groupID)] ~= true then return end

    self._logger:debug("Adding supply hub commands for group: " .. tostring(groupID))

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then return end

    local unit = group:getUnit(1)
    if unit == nil then return end

    ---@class LoadCargoCommandParams
    ---@field unitID number
    ---@field groupID number
    ---@field crateType CrateType
    ---@field supplyUnitsTracker SupplyUnitsTracker

    ---comment
    ---@param params LoadCargoCommandParams
    local loadCargoCommand = function(params)
        local crateType = params.crateType
        local supplyUnitsTracker = params.supplyUnitsTracker
        if supplyUnitsTracker then
            supplyUnitsTracker:UnitRequestCrateLoading(params.groupID, crateType)
        end
    end

    local path = { [1] = folderNames.supplyHub }

    
    ---@type LoadCargoCommandParams
    local farpParams1000 = { unitID = unit:getID(), groupID = group:getID(), crateType = "FARP_CRATE_1000", supplyUnitsTracker = self._supplyUnitsTracker }
    missionCommands.addCommandForGroup(groupID, "Load FARP Crate (1000)", path, loadCargoCommand, farpParams1000)

    ---@type LoadCargoCommandParams
    local farpParams2000 = { unitID = unit:getID(), groupID = group:getID(), crateType = "FARP_CRATE_2000", supplyUnitsTracker = self._supplyUnitsTracker }
    missionCommands.addCommandForGroup(groupID, "Load FARP Crate (2000)", path, loadCargoCommand, farpParams2000)

    ---@type LoadCargoCommandParams
    local samParms1000 = { unitID = unit:getID(), groupID = group:getID(), crateType = "SAM_CRATE_2000",  supplyUnitsTracker = self._supplyUnitsTracker }
    missionCommands.addCommandForGroup(groupID, "Load SAM Crate (1000)", path, loadCargoCommand, samParms1000)

    ---@type LoadCargoCommandParams
    local samParms2000 = { unitID = unit:getID(), groupID = group:getID(), crateType = "SAM_CRATE_2000",  supplyUnitsTracker = self._supplyUnitsTracker }
    missionCommands.addCommandForGroup(groupID, "Load SAM Crate (2000)", path, loadCargoCommand, samParms2000)

    ---@type LoadCargoCommandParams
    local samParms2000 = { unitID = unit:getID(), groupID = group:getID(), crateType = "AIRBASE_CRATE_2000",  supplyUnitsTracker = self._supplyUnitsTracker }
    missionCommands.addCommandForGroup(groupID, "Airbase Crate (2000)", path, loadCargoCommand, samParms2000)
end

function MissionCommandsHelper:AddCargoCommands(groupID)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then return end

    local unit = group:getUnit(1)
    if unit == nil then return end

    ---@class UnloadCargoCommandParams
    ---@field unitID number
    ---@field crateType CrateType
    ---@field supplyUnitsTracker SupplyUnitsTracker

    ---comment
    ---@param params UnloadCargoCommandParams
    local unloadCargoCommand = function(params)
        local unitID = params.unitID
        local crateType = params.crateType
        params.supplyUnitsTracker:UnloadRequested(unitID, crateType)
    end

    local cargo = self._supplyUnitsTracker:GetCargoInUnit(unit:getID())
    if cargo then
        for cargoType, amount in pairs(cargo) do
            local cargoConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(cargoType)
            if cargoConfig then
                for i = 1, amount do
                    local path = { [1] = folderNames.cargo }
                    ---@type UnloadCargoCommandParams
                    local params = { unitID = unit:getID(), crateType = cargoType, supplyUnitsTracker = self._supplyUnitsTracker }
                    missionCommands.addCommandForGroup(groupID, "Unload " .. cargoConfig.displayName, path, unloadCargoCommand, params)
                end
            end
        end
    end
end



---@private
---@param groupId integer
function MissionCommandsHelper:addMissionFolders(groupId)

    missionCommands.addSubMenuForGroup(groupId, folderNames.primary)
    missionCommands.addSubMenuForGroup(groupId, folderNames.secondary)

    if self._supplyHubGroups[tostring(groupId)] == true then
        self._logger:debug("Adding supply hub commands folder for group: " .. tostring(groupId))
        missionCommands.addSubMenuForGroup(groupId, folderNames.supplyHub)
    end

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupId)
    if group == nil then return end

    local unit = group:getUnit(1)
    if unit == nil then return end

    local cargo = self._supplyUnitsTracker:GetCargoInUnit(unit:getID())
    if cargo ~= nil then
        missionCommands.addSubMenuForGroup(groupId, folderNames.cargo)
    end
end

---@private
---@param groupId integer
function MissionCommandsHelper:removeMissionFolders(groupId)
    missionCommands.removeItemForGroup(groupId, { folderNames.primary })
    missionCommands.removeItemForGroup(groupId, { folderNames.secondary })
    missionCommands.removeItemForGroup(groupId, { folderNames.supplyHub })
    missionCommands.removeItemForGroup(groupId, { folderNames.cargo })
end

---@private
function MissionCommandsHelper:ResetFolders(groupID)
    -- Cleanup mission folder
    self:removeMissionFolders(groupID)

    -- Add mission folders
    self:addMissionFolders(groupID)
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.MissionCommandsHelper = MissionCommandsHelper
