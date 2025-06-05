

---@class BuildableMission : Mission, SupplyUnitSpawnedListener
---@field private _requiredKilos number
---@field private _droppedKilos number
---@field private _crateType SupplyType
---@field private _targetZone SpearheadTriggerZone
---@field private _database Database
---@field private _onCrateDroppedOfListeners Array<OnCrateDroppedListener>
---@field private _markIDsPerGroup table<string, number>
---@field private _supplyUnitsTracker SupplyUnitsTracker 
---@field private _noLandingZone SpearheadTriggerZone?
---@field private _dropOffZone SpearheadTriggerZone?
---@field private _noLandingZoneId number
---@field private _dropOffZoneId number
local BuildableMission = {}
BuildableMission.__index = BuildableMission

---@class OnCrateDroppedListener 
---@field OnCrateDroppedOff fun(self:OnCrateDroppedListener, mission:BuildableMission, kilos:number)

---@param database Database
---@param targetZone SpearheadTriggerZone
---@param requiredKilos number
---@param requiredCrateType SupplyType
---@param noLandingZone SpearheadTriggerZone?
---@param logger Logger
function BuildableMission.new(database, logger, targetZone, noLandingZone, requiredKilos, requiredCrateType)

    local Mission = Spearhead.classes.stageClasses.missions.baseMissions.Mission
    setmetatable(BuildableMission, Mission)

    local self = setmetatable({}, { __index = BuildableMission })
    
    self._targetZone = targetZone
    self._database = database
    self._requiredKilos = requiredKilos
    self._droppedKilos = 0

    self._noLandingZone = noLandingZone

    if noLandingZone then

        local verts = noLandingZone.verts
        local enlarged = Spearhead.Util.enlargeConvexHull(verts, 300)

        ---@type SpearheadTriggerZone
        local dropOfZone = {
            name = targetZone.name .. "_dropZone",
            zone_type = "Polygon",
            radius = 0,
            verts = enlarged,
            location = noLandingZone.location,
        }

        self._dropOffZone = dropOfZone
    end

    self.code = tostring(database:GetNewMissionCode())
    self.name = "Resupply"

    local type = "site"
    if requiredCrateType == "SAM_CRATE" then
        type = "SAM site"
    elseif requiredCrateType == "FARP_CRATE" then
        type = "FARP"
    end

    self.zoneName = targetZone.name .. "_supply"
    self._logger = logger
    self._onCrateDroppedOfListeners = {}
    self._completeListeners = {}
    self._markIDsPerGroup = {}
    self._supplyUnitsTracker = Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker.getOrCreate(logger.LogLevel)
    self._state = "NEW"


    self.location = targetZone.location

    self.missionType = "LOGISTICS"
    self.missionTypeDisplay = "LOGISTICS"

    self.priority = "secondary"

    self._missionCommandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(self._logger.LogLevel)

    self._crateType = requiredCrateType

    return self
end

---@param listener OnCrateDroppedListener
function BuildableMission:AddOnCrateDroppedOfListener(listener)
    table.insert(self._onCrateDroppedOfListeners, listener)
end

function BuildableMission:ShowBriefing(groupID)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then return end

    local unitType = Spearhead.DcsUtil.getUnitTypeFromGroup(group)
    local coords = Spearhead.DcsUtil.convertVec2ToUnitUsableType(self.location, unitType)

    local siteType = "FARP"
    if self._crateType == "SAM_CRATE" then
        siteType = "SAM site"
    elseif self._crateType == "AIRBASE_CRATE"  then
        siteType = "airbase"
    end

    local briefing = "Mission [" .. self.code .. "] " .. self.name .. 
        "\n \n" ..
        "We've dispatched forward units to find a proper spot for a new " .. siteType .. "." ..
        "\nYou will need to drop off supplies so they can start building." ..
        "\nThe coords are: " .. coords ..
        "\n\n" ..
        "\nKilos still required: " .. self._requiredKilos - self._droppedKilos ..
        "\n\n" ..
        "NOTE: Do not land in the orange construction zone!"

    trigger.action.outTextForGroup(groupID, briefing, 30)
end

function BuildableMission:MarkMissionAreaToGroup(groupID)

    if self._markIDsPerGroup[groupID] then
        Spearhead.DcsUtil.RemoveMark(self._markIDsPerGroup[groupID])
    end

    local text = "[" .. self.code .. "] " .. self.name .. " | " .. self._crateType
    local location = { x= self.location.x, y=land.getHeight(self.location), z=self.location.y }
    local markID = Spearhead.DcsUtil.AddMarkToGroup(groupID, text, location)

    self._markIDsPerGroup[groupID] = markID
end

---@private
---@param crate SupplyConfig
function BuildableMission:NotifyCrateDroppedOf(crate)
    for _, listener in ipairs(self._onCrateDroppedOfListeners) do
        if listener.OnCrateDroppedOff then
            listener:OnCrateDroppedOff(self, crate.weight)
        end
    end
end

function BuildableMission:SpawnActive()

    if self._state ~= "NEW" then
        self._logger:debug("Mission already spawned: " .. self.code)
        return
    end

    self._logger:debug("Spawning buildable mission: " .. self.code)

    if self._noLandingZone == nil then
        self._logger:error("No nolanding zone found for mission: " .. self.code)
        return
    end

    ---@type DrawColor
    local lineColor = { r=230/255, g=93/255, b=49/255, a=1}
    ---@type DrawColor
    local fillColor = { r=230/255, g=93/255, b=49/255, a=0.2}
    self._noLandingZoneId = Spearhead.DcsUtil.DrawZone(self._noLandingZone, lineColor, fillColor, 6)

    if self._dropOffZone == nil then
        self._logger:error("No drop off zone found for mission: " .. self.code)
        return
    end

    local lineColor2 = { r=0, g=0, b=1, a=1}
    local fillColor2 = { r=0, g=0, b=1, a=0}
    self._dropOffZoneId = Spearhead.DcsUtil.DrawZone(self._dropOffZone, lineColor2, fillColor2, 6)
    
    ---@param selfA BuildableMission
    ---@param time number
    local checkForCrateTasks = function (selfA, time)
        selfA:CheckCratesInZone()

        if selfA:getState() == "COMPLETED" then
            return nil
        end

        return time + 10
    end

    timer.scheduleFunction(checkForCrateTasks, self, timer.getTime() + 10)

    self:SpawnForwardUnits()
    self._state = "ACTIVE"

    self._missionCommandsHelper:AddMissionToCommands(self)
    self._supplyUnitsTracker:AddOnSupplyUnitSpawnedListener(self)

    local units = self._supplyUnitsTracker:GetUnits()
    if units then
        for _, unit in pairs(units) do
            if unit and unit:isExist() then
                local group = unit:getGroup()
                if group then
                    self:MarkMissionAreaToGroup(group:getID())
                end
            end
        end
    end
end

function BuildableMission:SpawnForwardUnits()

end

---@param unit Unit
function BuildableMission:SupplyUnitSpawned(unit)

    if self._state ~= "ACTIVE" then return end

    local group = unit:getGroup()
    if group == nil then return end

    self:MarkMissionAreaToGroup(unit:getGroup():getID())
end


function BuildableMission:CheckCratesInZone()

    ---@type Array<Object>
    local foundCrates = {}

    local crates = self._supplyUnitsTracker:GetCargoCratesDropped()
    for _, staticObject in pairs(crates) do
        if staticObject and staticObject:isExist() and Spearhead.Util.startswith(staticObject:getName(), self._crateType, true) then
            local pos = staticObject:getPoint()

            if Spearhead.Util.is3dPointInZone(pos, self._dropOffZone) then
                table.insert(foundCrates, staticObject)
            end
        end
    end
    
    for _, foundCrate in pairs(foundCrates) do 
        local crateConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.fromObjectName(foundCrate:getName())
        if crateConfig then
            self._droppedKilos = self._droppedKilos + crateConfig.weight
            foundCrate:destroy()
            self:NotifyCrateDroppedOf(crateConfig)
        end
    end

    if self._droppedKilos >= self._requiredKilos then
        Spearhead.DcsUtil.RemoveMark(self._noLandingZoneId)
        Spearhead.DcsUtil.RemoveMark(self._dropOffZoneId)
        self:NotifyMissionComplete()
        self._state = "COMPLETED"
    end
    
    if self._state == "COMPLETED" then
        for groupID, markID in pairs(self._markIDsPerGroup) do
            if markID then
                Spearhead.DcsUtil.RemoveMark(markID)
                self._markIDsPerGroup[groupID] = nil
            end
        end
    end

end


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.BuildableMission = BuildableMission