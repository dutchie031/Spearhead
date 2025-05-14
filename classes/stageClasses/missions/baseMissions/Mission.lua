


---@class Mission
---@field name string
---@field zoneName string
---@field missionType MissionType
---@field missionTypeDisplay string
---@field priority MissionPriority
---@field location Vec2?
---@field code string
---@field protected _state MissionState 
---@field protected _missionBriefing string
---@field getState fun(self: Mission): MissionState @Get the mission state
---@field protected _logger Logger
---@field protected _database Database
---@field protected _missionCommandsHelper MissionCommandsHelper
---@field protected _completeListeners Array<MissionCompleteListener>
local Mission = {}
Mission.__index = Mission

--- @class MissionCompleteListener 
--- @field OnMissionComplete fun(self: any, mission:Mission)

---@protected
---@param self Mission
---@param zoneName string
---@param missionName string
---@param missionType MissionType
---@param missionBriefing string
---@param priority MissionPriority
---@param database Database
---@param logger Logger
---@return boolean, string 
function Mission.newSuper(self, zoneName, missionName, missionType, missionBriefing, priority, database, logger)

    self.zoneName = zoneName
    self.name = missionName
    self.missionType = missionType
    self.priority = priority
    self._state = "NEW"
    self._logger = logger
    self._database = database
    self._missionBriefing = missionBriefing
    self.code = tostring(database:GetNewMissionCode())

    self._completeListeners = {}

    self.location = database:GetLocationForMissionZone(zoneName)
    self.missionTypeDisplay = self.missionType
    
    self._missionCommandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(logger.LogLevel)

    return true, "success"
end

---@return MissionState
function Mission:getState()
    return self._state
end

--region PUBLIC

function Mission:SpawnPersistedState() end
function Mission:SpawnActive() end

---comment
---@param checkHealth boolean
---@param messageIfDone boolean
function Mission:UpdateState(checkHealth, messageIfDone) end
function Mission:StartCheckingContinuous() end


---comment
---@param groupId number
function Mission:ShowBriefing(groupId)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupId)
    if group == nil then return end

    local unitType = Spearhead.DcsUtil.getUnitTypeFromGroup(group)
    local coords = Spearhead.DcsUtil.convertVec2ToUnitUsableType(self.location, unitType)
    self._logger:debug("Coords converted: " .. coords)

    local stateString = self:ToStateString()
    if self._missionBriefing == nil or self._missionBriefing == "" then self._missionBriefing = "No briefing available" end

    local briefing = self._missionBriefing

    briefing = Spearhead.Util.replaceString(briefing, "{{coords}}", coords)
    briefing = Spearhead.Util.replaceString(briefing, "{{ coords }}", coords)

    local text = "Mission [" ..
    self.code .. "] " .. self.name .. "\n \n" .. briefing .. " \n \n" .. stateString
    trigger.action.outTextForGroup(groupId, text, 30);
end


---@param listener MissionCompleteListener Object that implements "OnMissionComplete(self, mission)"
function Mission:AddMissionCompleteListener(listener)
    if type(listener) ~= "table" then
        return
    end
    table.insert(self._completeListeners, listener)
end

function Mission:NotifyMissionComplete()
    self._missionCommandsHelper:RemoveMissionToCommands(self)
    self._logger:info("Mission Completed: " .. self.zoneName)
    trigger.action.outText("Mission " .. self.name .. " [" .. self.code .. "] was completed succesfully", 20)

    for _, listener in pairs(self._completeListeners) do
        pcall(function()
            listener:OnMissionComplete(self)
        end)
    end

    local succ, err = pcall(function()
        SpearheadAPI.Internal.notifyMissionComplete(self.zoneName)
    end)

end

---endregion

--region PROTECTED

---@protected
function Mission:ToStateString() return "status: in progress" end


--endregion



if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
if not Spearhead.classes.stageClasses.missions.baseMissions then Spearhead.classes.stageClasses.missions.baseMissions = {} end
Spearhead.classes.stageClasses.missions.baseMissions.Mission = Mission




do --aliases

    --- @alias MissionPriority
    --- | "none"
    --- | "primary"
    --- | "secondary"

    --- @alias MissionType
    --- | "nil"
    --- | "STRIKE"
    --- | "BAI"
    --- | "DEAD"
    --- | "SAM"
    --- | "OCA"

    --- @alias MissionState
    --- | "NEW"
    --- | "WAITING"
    --- | "ACTIVE"
    --- | "COMPLETED"

end


