---@class SpawnManager : OnUnitLostListener
---@field private _persistedUnits table<string,boolean>
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
            ONLY when perstable data is found.
        ]]

        if spawnTemplate and spawnTemplate["units"] then
            for _, unit in pairs(spawnTemplate["units"]) do
                local name = unit["name"]

                Spearhead.Events.addOnUnitLostEventListener(name, self)
                local state = Spearhead.classes.persistence.Persistence.UnitState(name)
                if state then
                    if state.isDead == true then
                        removeableUnitNames[#removeableUnitNames+1] = name
                    end
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

            return group
        end

        
        return nil
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

--Old Spawn Method

-- --- spawns the units as specified in the mission file itself
-- --- location and route can be nil and will then use default route
-- ---@param groupName string
-- ---@param location table? vector 3 data. { x , z, alt }
-- ---@param route table? route of the group. If nil wil be the default route.
-- ---@param uncontrolled boolean? Sets the group to be uncontrolled on spawn
-- ---@param countryId CountryID? Overwrites the country
-- ---@param emptyLoadouts boolean? If true, the group will spawn with empty loadouts
-- ---@return table? new_group the Group class that was spawned
-- ---@return boolean? isStatic whether the group is a static or not
-- function DCS_UTIL.SpawnGroupTemplate(groupName, location, route, uncontrolled, countryId, emptyLoadouts)
--     if groupName == nil then
--         return nil, nil
--     end

--     local template = DCS_UTIL.GetMizGroupOrDefault(groupName, nil)
--     if template == nil then
--         return nil, nil
--     end
--     if template.category == DCS_UTIL.GroupCategory.STATIC then
--         --TODO: Implement location and route stuff
--         local spawn_template = template.group_template
--         local country = countryId or template.country_id

--         ---disable diagnostic as -1 is actually valid
--         ---@diagnostic disable-next-line: param-type-mismatch
--         coalition.addGroup(country, -1, spawn_template)

--         local object = StaticObject.getByName(spawn_template.name)
--         if object then
--             return object, true
--         end
--     else
--         local spawn_template = Spearhead.Util.deepCopyTable(template.group_template)
--         if location ~= nil then
--             local x_offset
--             if location.x ~= nil then x_offset = spawn_template.x - location.x end

--             local y_offset
--             if location.z ~= nil then y_offset = spawn_template.y - location.z end

--             spawn_template.x = location.x
--             spawn_template.y = location.z

--             for i, unit in pairs(spawn_template.units) do
--                 unit.x = unit.x - x_offset
--                 unit.y = unit.y - y_offset
--                 unit.alt = location.alt
--             end
--         end

--         if spawn_template.units then
--             for _, unit in pairs(spawn_template.units) do
--                 if unit["parking"] then
--                     unit["parking_landing"] = unit["parking"]
--                 end

--                 if unit["parking_id"] then
--                     unit["parking_landing_id"] = unit["parking_id"]
--                 end
--             end

--             if emptyLoadouts == true then
--                 for _, unit in pairs(spawn_template.units) do
--                     if unit["payload"] and unit["payload"]["pylons"] then
--                         unit["payload"]["pylons"] = {}
--                     end
--                 end
--             end
--         end

--         if route ~= nil then
--             spawn_template.route = route
--         end

--         if uncontrolled ~= nil then
--             spawn_template.uncontrolled = uncontrolled
--         end

--         local country = countryId or template.country_id
--         local new_group = coalition.addGroup(country, template.category, spawn_template)
--         return new_group, false
--     end
-- end
