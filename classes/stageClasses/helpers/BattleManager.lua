---@class BattleManager
---@field private _name string
---@field private _logger Logger
---@field private _redGroups Array<SpearheadGroup>
---@field private _blueGroups Array<SpearheadGroup>
---@field private _redShootAtPoints Array<Vec2>
---@field private _blueShootAtPoints Array<Vec2>
---@field private _isActive boolean
local BattleManager = {}
BattleManager.__index = BattleManager

---@param redGroups Array<SpearheadGroup>
---@param blueGroups Array<SpearheadGroup>
---@param name string
---@param logLevel LogLevel
---@return BattleManager
function BattleManager.New(redGroups, blueGroups, name, logLevel)
    local self = setmetatable({}, BattleManager)

    self._isActive = false
    self._name = name
    self._logger = Spearhead.LoggerTemplate.new("BattleManager_" .. name, logLevel)

    self._redGroups = redGroups
    self._blueGroups = blueGroups

    self._logger:debug("BattleManager created with name: " .. self._name 
        .. ", red groups: " .. #self._redGroups 
        .. ", blue groups: " .. #self._blueGroups)

    return self
end

---@param self BattleManager
---@param time number
local function CheckTask(self, time)
    local interval = self:Update()
    if not interval then return end
    return time + interval
end

function BattleManager:Start()
    self._logger:info("BattleManager started: " .. self._name)
    self._isActive = true
    self:SetAllInvisible()

    timer.scheduleFunction(CheckTask, self, timer.getTime() + 5)
end

function BattleManager:Stop()
    self._isActive = false
    self:SetAllVisible()
end

---@private
function BattleManager:SetAllInvisible()
    for _, group in pairs(self._redGroups) do
        group:SetInvisible()
    end

    for _, group in pairs(self._blueGroups) do
        group:SetInvisible()
    end
end


---@private
function BattleManager:SetAllVisible()
    for _, group in pairs(self._redGroups) do
        group:SetVisible()
    end

    for _, group in pairs(self._blueGroups) do
        group:SetVisible()
    end
end

---comment
---@return number?
function BattleManager:Update()
    if self._isActive == false then
        return nil
    end

    self._logger:debug("BattleManager Update called for " .. self._name)

    local shootChance = 1 -- Adjust this value to control the shooting probability (0.0 to 1.0)

    self:LetUnitsShoot(self._redGroups, self._blueGroups)
    self:LetUnitsShoot(self._blueGroups, self._redGroups)

    return math.random(4, 10) -- Return a random interval between 5 and 10 seconds for the next update
end

---@private
---@param fromGroups Array<SpearheadGroup>
---@param targetGroups Array<SpearheadGroup>
---@return Array<Vec2>
function BattleManager:CalculateShootAtPoints(fromGroups, targetGroups)

    ---@type Array<Vec2>
    local result = {}
   
    for _, group in pairs(targetGroups) do
         ---@type Array<Vec2>
        local points = {}

        self._logger:debug("Processing red group: " .. group.groupName)
        local groupUnits = group:GetAsUnits()
        for _, unit in pairs(group:GetAsUnits()) do
            local pos = unit:getPoint()
            table.insert(points, {x = pos.x, y = pos.z})
        end

        local hull = Spearhead.Util.getConvexHull(points)
        local enlargedHull = Spearhead.Util.enlargeConvexHull(hull, 30) -- Enlarge the hull by 50 meters

        local randomGroup = Spearhead.Util.randomFromList(fromGroups) --[[@as SpearheadGroup]]
        if randomGroup then

            local randomUnit = Spearhead.Util.randomFromList(randomGroup:GetObjects()) --[[@as Object]]
            local pos = randomUnit:getPoint()

            ---@type Vec2
            local vec2 = {x = pos.x, y = pos.z}

            local shootPoints = Spearhead.Util.GetVisibleHullPointsFromOrigin(enlargedHull, vec2)
            for _, point in pairs(shootPoints) do
                table.insert(result, point)
            end
        end
    end
    return result

end

---@private
---@param groups Array<SpearheadGroup>
---@param targetGroups Array<SpearheadGroup>
function BattleManager:LetUnitsShoot(groups, targetGroups)

    local shootChance = math.random(3, 7) / 10

    for _, group in pairs(groups) do

        local units = group:GetAsUnits()

        for _, unit in pairs(units) do

            if self:IsUnitApplicable(unit) == true then
                if math.random() <= shootChance then
                    local unitPos = unit:getPoint()
                    local point = self:GetRandomPoint({x = unitPos.x, y = unitPos.z }, targetGroups)
                    if point then

                        local ammo, qty = self:getBestAmmo(unit)
                        local shootTask = {
                            id = "FireAtPoint",
                            params = {
                                point = point,
                                radius = 1,
                                expendQty = qty,
                                weaponType = ammo,
                                expendQtyEnabled = true,
                                counterbattaryRadius = math.random(5, 10)
                            }
                        }

                        self._logger:debug("Red unit " .. unit:getName() .. " will shoot " .. qty .. " rounds at point: " .. tostring(point))

                        local controller = unit:getController()
                        if controller then
                            controller:setTask(shootTask)
                        end
                    end
                end
            end
        end
    end
end 

---@param unit Unit
---@return number
---@return number 
function BattleManager:getBestAmmo(unit)

    local ammo = unit:getAmmo()

    if not ammo then return 3221225470, 1 end -- Default ammo if no ammo is found

    local shells = {}

    for _, entry in pairs(ammo) do
        if entry.count and entry.count > 0 then
            if entry.desc.category == Weapon.Category.SHELL then
                table.insert(shells, entry)
            end
        end
    end

    local entry = Spearhead.Util.randomFromList(shells)
    if entry.desc.warhead then
        local caliber = entry.desc.warhead.caliber
        if caliber > 50 then
            return 258503344128, 1
        else
            return 258503344129, 25
        end
    end
    return 3221225470, 1
end

---@private
---@param unit Unit
---@return boolean
function BattleManager:IsUnitApplicable(unit)
    if not unit or not unit:isExist() then
        return false
    end

    if
        unit:hasAttribute("AAA") == true
        or unit:hasAttribute("Air Defence") == true
        or unit:hasAttribute("Mobile AAA") == true
    then
        return false
    end

    return true
    
end

---@private
---@param origin Vec2
---@param groups Array<SpearheadGroup>
---@return Vec2?
function BattleManager:GetRandomPoint(origin, groups)
    local group = Spearhead.Util.randomFromList(groups) --[[@as SpearheadGroup]]
    if not group then return nil end

    local points = {}
    local groupUnits = group:GetAsUnits()
    for _, unit in pairs(group:GetAsUnits()) do
        local pos = unit:getPoint()
        table.insert(points, {x = pos.x, y = pos.z})
    end

    local hull = Spearhead.Util.getConvexHull(points)
    local enlargedHull = Spearhead.Util.enlargeConvexHull(hull, 30)
    local shootPoints = Spearhead.Util.GetVisibleHullPointsFromOrigin(enlargedHull, origin)
    return Spearhead.Util.randomFromList(shootPoints) --[[@as Vec2]]
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.BattleManager = BattleManager
