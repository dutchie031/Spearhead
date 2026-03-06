local AirGroup = require("classes.capClasses.airGroups.AirGroup")
local SWEEP = require("classes.capClasses.taskings.SWEEP")
local Util = require("classes.util.Util")
local MissionEditorWarner = require("classes.util.MissionEditorWarnings")

---@class SweepGroup : AirGroup
---@field _targetZoneIdPerStage table<number, string>
---@field _currentTargetZoneID string?
local SweepGroup = {}
SweepGroup.__index = SweepGroup


---@param groupName string
---@param config CapConfig
---@param logger Logger
---@param spawnManager SpawnManager
---@return SweepGroup
function SweepGroup.New(groupName, config, logger, spawnManager)
    setmetatable(SweepGroup, AirGroup)
    local self = setmetatable({}, SweepGroup) --[[@as SweepGroup]]
    AirGroup.New(self, groupName, "SWEEP", config, logger, spawnManager)

    self._targetZoneIdPerStage = {}
    self:InitWithName(groupName)

    return self
end

---@return string?
function SweepGroup:GetZoneIDWhenStageID(stageID)
    return self._targetZoneIdPerStage[stageID]
end

---@return string?
function SweepGroup:GetCurrentTargetZoneID()
    return self._currentTargetZoneID
end

---@class SetTaskParams
---@field task table
---@field self SweepGroup

---@param params SetTaskParams
local setMissionDelayedTask = function(params, time)
    params.self:SetMissionPrivate(params.task)
end

function SweepGroup:SendToZone(zone, targetZoneID, airbase)
    self._logger:debug("Airgroup " .. self._groupName .. " called to zone: " .. zone.name)

    self._currentTargetZoneID = targetZoneID

    local group = Group.getByName(self._groupName)

    local mission = SWEEP.getAsMissionFromAirbase(self._groupName, airbase, zone, self._config)
    if mission then
        ---@type SetTaskParams
        local params = {
            task = mission,
            self = self
        }
        local delay = math.random(120, 600)
        timer.scheduleFunction(setMissionDelayedTask, params, timer.getTime() + delay)
    else
        self._logger:error("SweepGroup:SendToZone - Mission could not be created for group: " .. self._groupName)
    end
end

function SweepGroup:SendToZoneInternal()


end

---@private
function SweepGroup:InitWithName(groupName)
    local split_string = Util.split_string(groupName, "_")
    local partCount = Util.tableLength(split_string)
    if partCount >= 3 then

        local configPart = split_string[2]
        configPart = string.sub(configPart, 2, #configPart)
        
        local subsplit = Util.split_string(configPart, "|")
        if subsplit then
            for key, value in pairs(subsplit) do
                local keySplit = Util.split_string(value, "]")
                local targetZone = keySplit[2]
                local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                local commaSeperated = Util.split_string(allActives, ",")
                for _, value in pairs(commaSeperated) do
                    local dashSeperated = Util.split_string(value, "-")
                    if Util.tableLength(dashSeperated) > 1 then
                        local from = tonumber(dashSeperated[1])
                        local till = tonumber(dashSeperated[2])

                        for i = from, till do
                            if Util.strContains(targetZone, "A") == true then
                                self._targetZoneIdPerStage[tostring(i)] = string.gsub(targetZone, "A", tostring(i))
                            else
                                self._targetZoneIdPerStage[tostring(i)] = targetZone
                            end
                        end
                    else
                        if Util.strContains(targetZone, "A") == true then
                            self._targetZoneIdPerStage[tostring(dashSeperated[1])] = string.gsub(targetZone, "A",
                                tostring(dashSeperated[1]))
                        else
                            self._targetZoneIdPerStage[tostring(dashSeperated[1])] = targetZone
                        end
                    end
                end
            end
        end

        env.info("SweepGroup parsed with table: " .. Util.toString(self._targetZoneIdPerStage))
    else
        MissionEditorWarner.Add("SWEEP Group with name: " ..
            groupName .. "should have at least 3 parts, but has " .. partCount)
    end
end

return SweepGroup