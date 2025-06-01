
---@class CapGroup : AirGroup
---@field private _targetZoneIdPerStage table<string, string>
---@field private _isBackup boolean
---@field private _currentTargetZoneID string?
local CapGroup = {}
CapGroup.__index = CapGroup


---@param groupName string
---@param config CapConfig
---@param logger Logger
---@return CapGroup
function CapGroup.New(groupName, config, logger)

    setmetatable(CapGroup, Spearhead.classes.capClasses.airGroups.AirGroup)
    local self = setmetatable({}, CapGroup) --[[@as CapGroup]]
    Spearhead.classes.capClasses.airGroups.AirGroup.New(self, groupName, "CAP", config, logger)

    self._targetZoneIdPerStage = {}

    self:InitWithName(groupName)

    return self
end

---@return boolean
function CapGroup:IsBackup()
    return self._isBackup
end

---@return string?
function CapGroup:GetZoneIDWhenStageID(stageID)
    return self._targetZoneIdPerStage[stageID]
end

---@return string?
function CapGroup:GetCurrentTargetZoneID()
    return self._currentTargetZoneID
end

---@param zone SpearheadTriggerZone
---@param targetZoneID string
---@param airbase Airbase
function CapGroup:SendToZone(zone, targetZoneID, airbase)

    self._logger:debug("Airgroup " .. self._groupName .. " called to zone: " .. zone.name)

    self._currentTargetZoneID = targetZoneID
    local group = Group.getByName(self._groupName)

    local isInAir = false
    if group then
        local units = group:getUnits()
        for _, unit in pairs(units) do
            if unit:inAir() == true then
                isInAir = true
                break
            end
        end
    else
        self._logger:debug("CapGroup:SendToZone - Group not found: " .. self._groupName)
        return
    end

    if isInAir == true then
        local mission = Spearhead.classes.capClasses.taskings.CAP.getAsMission(self._groupName, airbase, zone, self._config)
        self:SetMission(mission)
    else
        local mission = Spearhead.classes.capClasses.taskings.CAP.getAsMissionFromAirbase(self._groupName, airbase, zone, self._config)
        if mission then
            self:SetMission(mission)
        else
            self._logger:warn("CapGroup:SendToZone - Mission could not be created for group: " .. self._groupName)
            return
        end
    end
end

---@private
function CapGroup:InitWithName(groupName)
    local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "A" then
                self._isBackup = false
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "B" then
                configPart = string.sub(configPart, 2, #configPart)
                self._isBackup = true
            elseif first == "[" then
                self._isBackup = false
            else
                Spearhead.AddMissionEditorWarning("Could not parse the CAP config for group: " .. groupName)
                return
            end

            

            local subsplit = Spearhead.Util.split_string(configPart, "|")
            if subsplit then
                for key, value in pairs(subsplit) do
                    local keySplit = Spearhead.Util.split_string(value, "]")
                    local targetZone = keySplit[2]
                    local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                    local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                    for _, value in pairs(commaSeperated) do
                        local dashSeperated = Spearhead.Util.split_string(value, "-")
                        if Spearhead.Util.tableLength(dashSeperated) > 1 then
                            local from = tonumber(dashSeperated[1])
                            local till = tonumber(dashSeperated[2])

                            for i = from, till do
                                if Spearhead.Util.strContains(targetZone, "A") == true then
                                    self._targetZoneIdPerStage[tostring(i)] = string.gsub(targetZone, "A", tostring(i))
                                else
                                    self._targetZoneIdPerStage[tostring(i)] = targetZone
                                end
                            end
                        else
                            if Spearhead.Util.strContains(targetZone, "A") == true then
                                self._targetZoneIdPerStage[tostring(dashSeperated[1])] = string.gsub(targetZone, "A", tostring(dashSeperated[1]))
                            else
                                self._targetZoneIdPerStage[tostring(dashSeperated[1])] = targetZone
                            end
                        end
                    end
                end
            end

            env.info("Capgroup parsed with table: " .. Spearhead.Util.toString(self._targetZoneIdPerStage))

        else
            Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.airGroups then Spearhead.classes.capClasses.airGroups = {} end
Spearhead.classes.capClasses.airGroups.CapGroup = CapGroup