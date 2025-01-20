

---@class StageBase 
---@field private _database Database
---@field private _logger Logger
---@field private _red_groups Array<SpearheadGroup>
---@field private _blue_groups Array<SpearheadGroup>
---@field private _cleanup_units table<string, boolean>
---@field private _airbase table?
---@field private _initialSide number?
local StageBase = {}

---comment
---@param databaseManager table
---@param logger table
---@param airbaseId integer
---@return StageBase
function StageBase.New(databaseManager, logger, airbaseId)

    StageBase.__index = StageBase
    local self = setmetatable({}, StageBase)

    self._database = databaseManager
    self._logger = logger

    self._red_groups = {}
    self._blue_groups = {}
    self._cleanup_units = {}

    self._airbase = Spearhead.DcsUtil.getAirbaseById(airbaseId)
    self._initialSide = Spearhead.DcsUtil.getStartingCoalition(airbaseId)

    do --init
        local redUnitsPos = {}
        local blueUnitsPos = {}

        do -- fill tables
            local redGroups = databaseManager:getRedGroupsAtAirbase(airbaseId)
            if redGroups then
            for _, groupName in pairs(redGroups) do
                local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
                table.insert(self._red_groups, shGroup)

                for _, unit in shGroup:GetUnits() do
                    redUnitsPos[unit:getName()] = unit:getPoint()
                end

                shGroup:Destroy()
            end
            end

            local blueGroups = databaseManager:getBlueGroupsAtAirbase(airbaseId)
            if blueGroups then
            for _, groupName in pairs(blueGroups) do
                local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
                table.insert(self._blue_groups, shGroup)

                for _, unit in shGroup:GetUnits() do
                    blueUnitsPos[unit:getName()] = unit:getPoint()
                end

                shGroup:Destroy()
            end
            end
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
                        self._cleanup_units[redUnitName] = true
                    end
                end
            end
        end
    end

    return self
end  

---@private
function StageBase:SpawnRedUnits()

    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._red_groups, timer.getTime() + 3)
end

---@private
function StageBase:CleanRedUnits()
    for _, value in pairs(self._red_groups) do
        value:SpawnCorpsesOnly()
    end

    for _, unitName in pairs(self._cleanup_units) do
        Spearhead.DcsUtil.DestroyUnit(unitName)
        Spearhead.DcsUtil.CleanCorpse(unitName)
    end

end

---@private
function StageBase:SpawnBlueUnits()

    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._blue_groups, timer.getTime() + 3)
end

function StageBase:ActivateRedStage()
    if self._initialSide == 2 and self._airbase then
        self._airbase:setCoalition(1)
        self._airbase:autoCapture(false)
    end
    self:SpawnRedUnits()
end

function StageBase:ActivateBlueStage()
    if self._initialSide == 2 and self._airbase then
        self._airbase:setCoalition(2)
    end

    self:CleanRedUnits()
    self:SpawnBlueUnits()

end


if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.StageBase = StageBase



