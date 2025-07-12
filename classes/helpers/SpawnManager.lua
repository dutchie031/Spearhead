---@class SpawnManager : OnUnitLostListener
---@field private _persistedUnits table<string,boolean>
---@field private _persistedMovingGroups table<string,boolean>
---@field private _logger Logger
local SpawnManager = {}
SpawnManager.__index = SpawnManager

---@class SpawnOverrides
---@field countryID number?
---@field emptyLoadouts boolean? if true, the group will spawn with empty loadouts
---@field route table? route of the group. If nil will be the default route.
---@field uncontrolled boolean? Sets the group to be uncontrolled on spawn

---@param logger Logger
function SpawnManager.new(logger)
    local self = setmetatable({}, SpawnManager)

    self._logger = logger

    self._persistedUnits = {} -- Stores units that should be persisted by name
    self._persistedMovingGroups = {} -- Stores moving units that should be persisted by name

    self:StartUpdatingPersistedMovingUnits()

    return self
end

---comment
---@param groupName string
---@param overrides SpawnOverrides? overrides for the spawn
---@param isGroupPersistant boolean? whether or not a group and all its units should be persisted.
---@return StaticObject|Group|nil spawned
---@return boolean isStatic
function SpawnManager:SpawnGroup(groupName, overrides, isGroupPersistant)
    
    local spawnData = Spearhead.classes.helpers.MizGroupsManager.getSpawnTemplateData(groupName)

    if spawnData == nil then
        env.error("SpawnManager:SpawnGroup - No spawn template found for group: " .. groupName)
        return nil, false
    end

    if spawnData.isStatic == true then
        return self:SpawnStaticInternal(groupName, spawnData, overrides, isGroupPersistant), true
    else
        return self:SpawnGroupInternal(groupName, spawnData, overrides, isGroupPersistant), false
    end
end

function SpawnManager:DestroyGroup(groupName)
    if groupName == nil then return end
    
    if self:IsGroupStatic(groupName) == true then
        local object = StaticObject.getByName(groupName)
        if object ~= nil then
            object:destroy()
        else
            env.error("SpawnManager:DestroyGroup - Static object not found: " .. groupName)
        end
    else
        local group = Group.getByName(groupName)
        if group and group:isExist() then
            group:destroy()
        else
            env.error("SpawnManager:DestroyGroup - Group not found or does not exist: " .. groupName)
        end
    end
end

---comment
---@param groupName string
---@return boolean
function SpawnManager:IsGroupStatic(groupName)
    local isStatic = Spearhead.classes.helpers.MizGroupsManager.IsGroupStatic(groupName)
    if isStatic ~= nil then return isStatic end

    return StaticObject.getByName(groupName) ~= nil
end


---@param object Object
function SpawnManager:OnUnitLost(object)
    local name = object:getName()

    if self._persistedUnits[name] then
        local heading = 0
        local pos = object:getPosition()
        if pos then
            heading = math.atan2(pos.x.z, pos.x.x)
            if heading < 0 then
				heading = heading + 2*math.pi
			end
            heading = heading
        end

        Spearhead.classes.persistence.Persistence.UnitKilled(
            name,
            object:getPoint(),
            heading,
            object:getTypeName()
        )
    end
end

function SpawnManager:SpawnCorpsesOnly(groupName)

end

do --- privates

    ---@private 
    ---@param groupName string
    ---@param spawnData SpawnData
    ---@param override SpawnOverrides?
    ---@param isPersistent boolean?
    ---@return Group|nil
    function SpawnManager:SpawnGroupInternal(groupName, spawnData, override, isPersistent)

        if not spawnData then return end

        local country = spawnData.country
        if override then
            country = override.countryID or spawnData.country
        end

        local spawnTemplate = Spearhead.Util.deepCopyTable(spawnData.groupTemplate)
        ---@type Array<string>
        local removeableUnitNames = {}
        --[[
            TODO: Spawn units at "current"/LastKnown position with them going to the next waypoint. 
            ONLY when persitable data is found.
        ]]

        if spawnTemplate and spawnTemplate["units"] then

            local firstAlive = nil

            for _, unit in pairs(spawnTemplate["units"]) do
                local name = unit["name"]

                Spearhead.Events.addOnUnitLostEventListener(name, self)
                local state = Spearhead.classes.persistence.Persistence.UnitState(name)
                if state then
                    if state.isDead == true then
                        removeableUnitNames[#removeableUnitNames+1] = name
                    else
                        if state.pos then
                            unit["x"] = state.pos.x
                            unit["y"] = state.pos.z
                            unit["heading"] = state.heading or 0
                        end
                        firstAlive = unit

                    end
                else
                   firstAlive = unit
                end

                if override and override.emptyLoadouts == true then
                    if unit["payload"] and unit["payload"]["pylons"] then
                        unit["payload"]["pylons"] = {}
                    end
                end

                if unit["parking"] then
                    unit["parking_landing"] = unit["parking"]
                end

                if unit["parking_id"] then
                    unit["parking_landing_id"] = unit["parking_id"]
                end
            end


            if override and override.route ~= nil then
                spawnTemplate["route"] = override.route
            end

            if firstAlive then
                spawnTemplate["x"] = firstAlive.x or spawnTemplate["x"] or 0
                spawnTemplate["y"] = firstAlive.y or spawnTemplate["y"] or 0

                if spawnTemplate["route"] and spawnTemplate["route"]["points"] then
                    local first = spawnTemplate["route"]["point"][1]
                    if first then
                        first["x"] = firstAlive.x or spawnTemplate["x"] or 0
                        first["y"] = firstAlive.y or spawnTemplate["y"] or 0
                    end
                end
            end

            if override and override.uncontrolled ~= nil then
                spawnTemplate["uncontrolled"] = override.uncontrolled
            end

            local group = coalition.addGroup(country, spawnData.category, spawnTemplate)


            for _, unit in pairs(group:getUnits()) do
                self:CheckUnitAndReplaceIfPersistentDead(unit)
                if isPersistent == true then
                    self._persistedUnits[unit:getName()] = true
                end
                Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
            end

            if self:HasMovingRoute(groupName) == true then
                local number = self:GetClosestWaypointNumber(spawnTemplate, firstAlive)
                if number then
                    self:SendGroupToWaypointDelayed(groupName, number)
                end

                if isPersistent == true then
                    self._persistedMovingGroups[groupName] = true
                end
            end

            return group
        end

        
        return nil
    end

    ---@private 
    ---@param groupName string
    ---@return boolean
    function SpawnManager:HasMovingRoute(groupName)
        local spawnData = Spearhead.classes.helpers.MizGroupsManager.getSpawnTemplateData(groupName)
        if spawnData and spawnData.groupTemplate and spawnData.groupTemplate.route and spawnData.groupTemplate.route.points then
            if Spearhead.Util.tableLength(spawnData.groupTemplate.route.points) > 1 then
                return true
            end
        end

        return false
    end

    ---@private 
    ---@param spawnTemplate table 
    ---@return number?
    function SpawnManager:GetClosestWaypointNumber(spawnTemplate, aliveLead)

        if not spawnTemplate or not spawnTemplate.route or not spawnTemplate.route.points then
            return 1
        end

        local points = spawnTemplate.route.points
        local posX = aliveLead.x
        local posY = aliveLead.y

        -- Find the segment (between two waypoints) closest to the unit's position
        local closestSegIdx = 1
        local closestDist = math.huge
        for i = 1, #points - 1 do
            local x1, y1 = points[i].x, points[i].y
            local x2, y2 = points[i+1].x, points[i+1].y
            -- Project aliveLead onto the segment
            local dx, dy = x2 - x1, y2 - y1
            local segLen2 = dx*dx + dy*dy
            local t = 0
            if segLen2 > 0 then
                t = ((posX - x1) * dx + (posY - y1) * dy) / segLen2
                t = math.max(0, math.min(1, t))
            end
            local projX = x1 + t * dx
            local projY = y1 + t * dy
            local dist = (projX - posX)^2 + (projY - posY)^2
            if dist < closestDist then
                closestDist = dist
                closestSegIdx = i
            end
        end
        -- Return the next waypoint index (the end of the closest segment)
        return math.min(closestSegIdx + 1, #points)
    end

    function SpawnManager:StartUpdatingPersistedMovingUnits()

        ---@class UpdateMovingUnitsParams
        ---@field self SpawnManager

        ---@type UpdateMovingUnitsParams
        local params = {
            self = self
        }

        ---@param params UpdateMovingUnitsParams
        local updateMovingUnitsTask = function(params, time)
            params.self:UpdatePersistedMovingUnits()
            return time + 60
        end

        timer.scheduleFunction(updateMovingUnitsTask, params, timer.getTime() + 60)
    end

    function SpawnManager:UpdatePersistedMovingUnits()
        for groupName, check in pairs(self._persistedMovingGroups) do
            if check == true then 
                local group = Group.getByName(groupName)
                if group and group:isExist() then
                    for _, unit in pairs(group:getUnits()) do
                        Spearhead.classes.persistence.Persistence.UpdateLocation(unit:getName(), unit:getPoint())
                    end
                else
                    self._persistedMovingGroups[groupName] = nil
                end
            end
        end
    end

    function SpawnManager:SendGroupToWaypointDelayed(groupName, waypointNumber)
        
        ---@class SendGroupToWaypointParams
        ---@field groupName string
        ---@field waypointNumber number

        ---@type SendGroupToWaypointParams
        local params = {
            groupName = groupName,
            waypointNumber = waypointNumber
        }

        ---comment
        ---@param params SendGroupToWaypointParams
        local sendGroupToWaypoint = function(params)

            local group = Group.getByName(params.groupName)
            if group and group:isExist() then
                local goToWaypoint= { 
                id = 'goToWaypoint', 
                    params = {
                        fromWaypointIndex = 0, -- Start from the first waypoint
                        goToWaypointIndex = params.waypointNumber,
                    }
                }

                local controller = group:getController()
                if controller then
                    controller:setCommand(goToWaypoint)
                end
            end
        end

        timer.scheduleFunction(sendGroupToWaypoint, params, timer.getTime() + 2)
    end

    ---@private
    ---@param groupName string
    ---@param spawnData SpawnData
    ---@param isPersistent any
    ---@param overrides SpawnOverrides?
    ---@return StaticObject?
    function SpawnManager:SpawnStaticInternal(groupName, spawnData, overrides, isPersistent)

        if not spawnData then return end

        local country = spawnData.country
        if overrides then
            country = overrides.countryID or spawnData.country
        end

        local spawnTemplate = Spearhead.Util.deepCopyTable(spawnData.groupTemplate)

        --for static Objecst groupNames and unit names are the same and is always 1:1
        local persistentState = Spearhead.classes.persistence.Persistence.UnitState(groupName)
        if persistentState then
            if persistentState.isDead == true then
                spawnTemplate["dead"] = true
                if persistentState.pos then
                    spawnTemplate["x"] = persistentState.pos.x
                    spawnTemplate["y"] = persistentState.pos.z
                    if spawnTemplate["units"] and spawnTemplate["units"][1] then
                        spawnTemplate["units"][1]["x"] = persistentState.pos.x
                        spawnTemplate["units"][1]["y"] = persistentState.pos.z
                        spawnTemplate["units"][1]["heading"] = persistentState.heading or 0
                    end
                end
            end
        end

        ---disable diagnostic as -1 is actually valid
        ---@diagnostic disable-next-line: param-type-mismatch
        coalition.addGroup(country, -1, spawnTemplate)

        local object = StaticObject.getByName(groupName)
        if object == nil then
            env.error("Could not retrieve spawned static object after spawning with name: " .. groupName)
            return nil
        end

        if isPersistent == true then
            self._persistedUnits[groupName] = true
            Spearhead.Events.addOnUnitLostEventListener(groupName, self)
        end

        return object
    end

    ---@private
    ---@param unit Unit
    function SpawnManager:CheckUnitAndReplaceIfPersistentDead(unit)

        if not unit then return end

        local deadState = Spearhead.classes.persistence.Persistence.UnitState(unit:getName())
        if deadState and deadState.isDead == true then
            unit:destroy() -- Destroy the unit if it is dead
            local staticObject = {
                ["heading"] = deadState.heading or 0,
                ["type"] = deadState.type or unit:getTypeName(),
                ["name"] = unit:getName() .. "_dead",
                ["x"] = deadState.pos.x,
                ["y"] = deadState.pos.z,
                ["dead"] = true,
            }
            coalition.addStaticObject(unit:getCountry(), staticObject)
        end
    end

end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.helpers then Spearhead.classes.helpers = {} end
Spearhead.classes.helpers.SpawnManager = SpawnManager
