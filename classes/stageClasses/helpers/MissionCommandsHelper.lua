---@class MissionCommandsHelper
---@field missionsByCode table<string, Mission> @table of missions by their code
---@field enabledByCode table<string, boolean> @table of enabled missions by their code
---@field updateNeeded boolean @flag to indicate if an update is needed
---@field lastUpdate number @last update time
---@field updateContinuous fun(self: MissionCommandsHelper, time: number): number @function to update commands continuously
---@field pinnedByGroup table<string, Mission> @table of pinned missions by group ID
---@field private _supplyHubGroups table<string, SupplyHub> @table of supply hub groups by their ID
---@field private _logger Logger @logger instance for logging
---@field private _supplyUnitsTracker SupplyUnitsTracker @supply units tracker instance
local MissionCommandsHelper = {}
MissionCommandsHelper.__index = MissionCommandsHelper

local instance = nil

---@return MissionCommandsHelper
---@param logLevel string @log level for the logger
function MissionCommandsHelper.getOrCreate(logLevel)
    if instance == nil then
        local self = setmetatable({}, MissionCommandsHelper)

        self._logger = Spearhead.LoggerTemplate.new("MissionCommandsHelper", logLevel)

        self.missionsByCode = {}
        self.enabledByCode = {}
        self.updateNeeded = false
        self.pinnedByGroup = {}
        self.lastUpdate = 0
        self._supplyHubGroups = {}
        self._supplyUnitsTracker = Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker.getOrCreate()

        ---comment
        ---@param selfA MissionCommandsHelper
        ---@param time number
        ---@return number
        self.updateContinuous = function(selfA, time)
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

        timer.scheduleFunction(self.updateContinuous, self, timer.getTime() + 5)
        Spearhead.Events.AddOnPlayerEnterUnitListener(self)
        instance = self
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

---@param groupID integer
---@param supplyHub SupplyHub
function MissionCommandsHelper:AddSupplyHubCommandsForGroup(groupID, supplyHub)
    if self._supplyHubGroups[tostring(groupID)] ~= nil and supplyHub:GetZoneName() == self._supplyHubGroups[tostring(groupID)]:GetZoneName() then
        return
    end

    self._logger:debug("Adding supply hub commands for group: " .. tostring(groupID))

    self._supplyHubGroups[tostring(groupID)] = supplyHub
    self:updateCommandsForGroup(groupID)
end

---@param groupID integer
function MissionCommandsHelper:RemoveSupplyHubCommandsForGroup(groupID)
    self._logger:debug("Removing supply hub commands for group: " .. tostring(groupID))
    self._supplyHubGroups[tostring(groupID)] = nil
    self:updateCommandsForGroup(groupID)
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

            return string.format("[%s] %-15s %-20s %10s nM\n", mission.code,  mission.missionTypeDisplay, mission.name, distanceText)
        end

        ---Primary missions
        text = text .. "Primary Missions\n"
        for code, enabled in pairs(self.enabledByCode) do
            
            if enabled == true then
                local mission = self.missionsByCode[code]
                if mission and mission.priority == "primary" then
                    text = text .. formatLine(mission)
                end
            end
        end

        ---Secondary missions
        text = text .. "\nSecondary Missions\n"
        for code, enabled in pairs(self.enabledByCode) do
            
            if enabled == true then
                local mission = self.missionsByCode[code]
                if mission and mission.priority == "secondary" then
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
        missionCommands.addCommandForGroup(groupId, "Briefing", path, missionBriefingRequested,{ groupId = groupId, mission = mission })
        missionCommands.addCommandForGroup(groupId, "Pin", path, pinMissionCommand, { self = self, groupId = groupId, mission = mission })
    end
end

---@private
---@param groupID integer
function MissionCommandsHelper:AddSupplyHubCommandsIfApplicable(groupID)

    local hub = self._supplyHubGroups[tostring(groupID)]
    if hub == nil then return end
    
    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then return end

    local unit = group:getUnit(1)
    if unit == nil then return end

    ---@class LoadCargoCommandParams
    ---@field unitID number
    ---@field groupID number
    ---@field crateType string
    ---@field hub SupplyHub

    ---comment
    ---@param params LoadCargoCommandParams
    local loadCargoCommand = function(params)
        local unitID = params.unitID
        local groupID = params.groupID
        local crateType = params.crateType
        local hubA = params.hub
        if hubA then
            hubA:UnitRequestCrateLoading(groupID, crateType)
        end

    end

    local path = { [1] = folderNames.supplyHub }
    ---@type LoadCargoCommandParams
    local params = { unitID = unit:getID(), groupID = group:getID(), crateType = "FARP_CRATE", hub = hub }
    missionCommands.addCommandForGroup(groupID, "Load FARP Crate", path, loadCargoCommand, params)

end

function MissionCommandsHelper:AddCargoCommands(groupID)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then return end

    local unit = group:getUnit(1)
    if unit == nil then return end

    ---@class UnloadCargoCommandParams
    ---@field unitID number
    ---@field crateType string
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
            local cargoConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[cargoType]
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

    if self._supplyHubGroups[tostring(groupId)] ~= nil then
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
