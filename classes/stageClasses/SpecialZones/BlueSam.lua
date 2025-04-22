
---@class BlueSam
---@field Activate fun(self: BlueSam)
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _blueGroups Array<SpearheadGroup>
---@field private _cleanupUnits table<string, boolean>
local BlueSam = {}

function BlueSam.New(database, logger, zoneName)
    BlueSam.__index = BlueSam
    local self = setmetatable({}, BlueSam)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    self._blueGroups = {}
    self._cleanupUnits = {}

    do
        local groups = database:getBlueSamGroupsInZone(zoneName)

        local blueUnitsPos = {}
        local redUnitsPos = {}

        for _, groupName in pairs(groups) do
            local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
            if SpearheadGroup then
                
                if SpearheadGroup:GetCoalition() == 2 then
                    table.insert(self._blueGroups, SpearheadGroup)
                end


                for _, unit in pairs(SpearheadGroup:GetUnits()) do
                    if SpearheadGroup:GetCoalition() == 1 then
                        table.insert(blueUnitsPos, unit:getPoint())
                    elseif SpearheadGroup:GetCoalition() == 2 then
                        table.insert(redUnitsPos, unit:getPoint())
                    end
                end

            end
            SpearheadGroup:Destroy()
        end

        do -- check cleanup requirements
            -- Checks is any of the units are withing range (5m) of another unit. 
            -- If so, make sure to add them to the cleanup list.
        
            local cleanup_distance = 5
            for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
                for redUnitName, redUnitPos in pairs(redUnitsPos) do
                    local distance = Spearhead.Util.VectorDistance(blueUnitPos, redUnitPos)
                    env.info("distance: " .. tostring(distance))
                    if distance <= cleanup_distance then
                        self._cleanupUnits[redUnitName] = true
                    end
                end
            end
        end
    end

    return self
end

function BlueSam:Activate()
    for unitName, needsCleanup in pairs(self._cleanupUnits) do
        if needsCleanup == true then
            Spearhead.DcsUtil.DestroyUnit(unitName)
        else
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
            end
        end
    end

    for _, group in pairs(self._blueGroups) do
        group:Spawn()
    end
end


if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.Missions.SpecialZones = BlueSam
