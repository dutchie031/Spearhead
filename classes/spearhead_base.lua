--- DEFAULT Values
if Spearhead == nil then Spearhead = {} end

local UTIL = {}
do -- INIT UTIL
    ---splits a string in sub parts by seperator
    ---@param input string
    ---@param seperator string
    ---@return table result list of strings
    function UTIL.split_string(input, seperator)
        if seperator == nil then
            seperator = " "
        end

        local result = {}
        if input == nil then
            return result
        end

        for str in string.gmatch(input, "[^" .. seperator .. "]+") do
            table.insert(result, str)
        end
        return result
    end

    ---comment
    ---@param table any
    ---@return number
    function UTIL.tableLength(table)
        if table == nil then return 0 end

        local count = 0
        for _ in pairs(table) do count = count + 1 end
        return count
    end

    ---Gets a random from the list
    ---@param list table
    function UTIL.randomFromList(list)
        local max = #list

        if max == 0 or max == nil then
            return nil
        end

        local random = math.random(0, max)
        if random == 0 then random = 1 end

        return list[random]
    end

    local function table_print(tt, indent, done)
        done = done or {}
        indent = indent or 0
        if type(tt) == "table" then
            local sb = {}
            for key, value in pairs(tt) do
                table.insert(sb, string.rep(" ", indent)) -- indent it
                if type(value) == "table" and not done[value] then
                    done[value] = true
                    table.insert(sb, key .. " = {\n");
                    table.insert(sb, table_print(value, indent + 2, done))
                    table.insert(sb, string.rep(" ", indent)) -- indent it
                    table.insert(sb, "}\n");
                elseif "number" == type(key) then
                    table.insert(sb, string.format("\"%s\"\n", tostring(value)))
                else
                    table.insert(sb, string.format(
                        "%s = \"%s\"\n", tostring(key), tostring(value)))
                end
            end
            return table.concat(sb)
        else
            return tt .. "\n"
        end
    end

    ---comment
    ---@param str string
    ---@param findable string
    ---@return boolean
    UTIL.startswith = function(str, findable)
        return str:find('^' .. findable) ~= nil
    end

    ---comment
    ---@param str string
    ---@param findable string
    ---@return boolean
    UTIL.strContains = function(str, findable)
        return str:find(findable) ~= nil
    end

    ---comment
    ---@param str string
    ---@param findableTable table
    ---@return boolean
    UTIL.startswithAny = function(str, findableTable)
        for key, value in pairs(findableTable) do
            if type(value) == "string" and UTIL.startswith(str, value) then return true end
        end
        return false
    end

    function UTIL.toString(something)
        if something == nil then
            return "nil"
        elseif "table" == type(something) then
            return table_print(something)
        elseif "string" == type(something) then
            return something
        else
            return tostring(something)
        end
    end
end
Spearhead.Util = UTIL

---DCS UTIL Takes inspiration from MIST but only takes the things it needs, changes for DCS updates and different vision for advanced mission scripting stuff.
---It also adds functions that make the other TDCS scripts easier without taking too much "control" away like MOOSE can sometimes.
local DCS_UTIL = {}
do     -- INIT DCS_UTIL
    do -- local databases
        --[[
            groupdata = {
                category,
                country_id,
                group_template
            }
        ]] --
        DCS_UTIL.__miz_groups = {}
        DCS_UTIL.__groupNames = {}
        DCS_UTIL.__blueGroupNames = {}
        DCS_UTIL.__redGroupNames = {}
        --[[
            zone = {
                name,

                zone_type,
                x,
                z,
                radius
                verts,

            }
        ]] --
        DCS_UTIL.__trigger_zones = {}
    end

    DCS_UTIL.Coalition =
    {
        NEUTRAL = 0,
        RED = 1,
        BLUE = 2
    }

    DCS_UTIL.ZoneType = {
        Cilinder = 0,
        Polygon = 2
    }

    DCS_UTIL.GroupCategory = {
        AIRPLANE   = 0,
        HELICOPTER = 1,
        GROUND     = 2,
        SHIP       = 3,
        TRAIN      = 4,
        STATIC     = 5 --CUSTOM CATEGORY
    }

    DCS_UTIL.__airbaseNamesById = {}

    DCS_UTIL.__airportsStartingCoalition = {}
    DCS_UTIL.__warehouseStartingCoalition = {}
    function DCS_UTIL.__INIT()
        do     -- INITS ALL TABLES WITH DATA THAT's from the MIZ environment
            do -- init group tables
                for coalition_name, coalition_data in pairs(env.mission.coalition) do
                    local coalition_nr = DCS_UTIL.stringToCoalition(coalition_name)
                    if coalition_data.country then
                        for country_index, country_data in pairs(coalition_data.country) do
                            for category_name, categorydata in pairs(country_data) do
                                local category_id = DCS_UTIL.stringToGroupCategory(category_name)
                                if category_id ~= nil and type(categorydata) == "table" and categorydata.group ~= nil and type(categorydata.group) == "table" then
                                    for group_index, group in pairs(categorydata.group) do
                                        local name = group.name
                                        if category_id == DCS_UTIL.GroupCategory.STATIC then
                                            local unit = group.units[1]
                                            name = unit.name
                                            local staticObj = {
                                                heading = unit.heading,
                                                name = unit.name,
                                                x = unit.x,
                                                y = unit.y,
                                                type = unit.type,
                                                dead = group.dead
                                            }

                                            if string.lower(unit.category) == "planes" then
                                                staticObj.livery_id = unit.livery_id
                                            end

                                            group = staticObj
                                        end

                                        table.insert(DCS_UTIL.__groupNames, name)
                                        DCS_UTIL.__miz_groups[name] =
                                        {
                                            category = category_id,
                                            country_id = country_data.id,
                                            group_template = group
                                        }

                                        if coalition_nr == 1 then
                                            table.insert(DCS_UTIL.__redGroupNames, name)
                                        elseif coalition_nr == 2 then
                                            table.insert(DCS_UTIL.__blueGroupNames, name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            do --init trigger zones
                for i, trigger_zone in pairs(env.mission.triggers.zones) do
                    local verticies = {}
                    if trigger_zone.verticies and type(trigger_zone.verticies) == "table" then
                        for ii, vert in pairs(trigger_zone.verticies) do
                            table.insert(verticies, { x = vert.x, z = vert.y })
                        end
                    end

                    --see if this works. Swap 3 and 4 to make sure points are ordered and edges can be created
                    local p4 = verticies[4]
                    local p3 = verticies[3]
                    verticies[3] = p4
                    verticies[4] = p3

                    local zone = {
                        name = trigger_zone.name,
                        zone_type = trigger_zone.type,
                        x = trigger_zone.x,
                        z = trigger_zone.y,
                        radius = trigger_zone.radius,
                        verts = verticies
                    }

                    DCS_UTIL.__trigger_zones[zone.name] = zone
                end
            end

            do -- init airports and warehouses
                if env.warehouses.airports then
                    for warehouse_id, value in pairs(env.warehouses.airports) do
                        if warehouse_id ~= nil then
                            warehouse_id = tostring(warehouse_id) or "nil"
                            local coalitionNumber = DCS_UTIL.stringToCoalition(value.coalition)
                            DCS_UTIL.__airportsStartingCoalition[warehouse_id] = coalitionNumber
                        end
                    end
                end

                if env.warehouses.warehouses then
                    DCS_UTIL.__warehouseStartingCoalition[-1] = "placeholder"
                    for warehouse_id, value in pairs(env.warehouses.warehouses) do
                        if warehouse_id ~= nil then
                            warehouse_id = tostring(warehouse_id) or "nil"
                            local coalitionNumber = DCS_UTIL.stringToCoalition(value.coalition)
                            DCS_UTIL.__warehouseStartingCoalition[warehouse_id] = coalitionNumber
                        end
                    end
                end
            end

            do -- fill airbaseNames
                local airbases = world.getAirbases()
                if airbases then
                    for _, airbase in pairs(airbases) do
                        local name = airbase:getName()
                        local id = tostring(airbase:getID())

                        if name and id then
                            DCS_UTIL.__airbaseNamesById[id] = name
                        end
                    end
                end
            end
        end
    end

    ---maps the coalition name to the DCS coalition integer
    ---@param input string the name
    ---@return integer
    function DCS_UTIL.stringToCoalition(input)
        --[[
            coalition.side = {
                NEUTRAL = 0
                RED = 1
                BLUE = 2
            }
        ]] --
        local input = string.lower(input)
        if input == 'neutrals' or input == "neutral" or input == "0" then
            return DCS_UTIL.Coalition.NEUTRAL
        end

        if input == 'red' or input == "1" then
            return DCS_UTIL.Coalition.RED
        end

        if input == 'blue' or input == "2" then
            return DCS_UTIL.Coalition.BLUE
        end

        return -1
    end

    ---checks if the groupname is a static group
    ---@param groupName any
    function DCS_UTIL.IsGroupStatic(groupName)
        return DCS_UTIL.__miz_groups[groupName].category == 5;
    end

    ---comment
    ---@param groupName string destroy the given group
    function DCS_UTIL.DestroyGroup(groupName)
        if DCS_UTIL.IsGroupStatic(groupName) then
            local object = StaticObject.getByName(groupName)
            if object ~= nil then
                object:destroy()
            end
        else
            local group = Group.getByName(groupName)
            if group and group:isExist() then
                group:destroy()
            end
        end
    end

    ---comment
    ---@param polygon table of pairs { x, z }
    ---@param x number X location
    ---@param z number Y location
    ---@return boolean
    function DCS_UTIL.IsPointInPolygon(polygon, x, z)
        local function isInComplexPolygon(polygon, x, z)
            local function getEdges(poly)
                local moved = {}
                moved[#poly] = poly[1]
                for i = 2, #poly do
                    moved[i - 1] = poly[i]
                end

                local result = {}
                for i = 1, #poly do
                    local point1 = moved[i]
                    local point2 = poly[i]
                    local edge = { x1 = point1.x, z1 = point1.z, x2 = point2.x, z2 = point2.z }
                    table.insert(result, edge)
                end
                return result
            end

            local edges = getEdges(polygon)
            local count = 0;
            for _, edge in pairs(edges) do
                if (x < edge.x1) ~= (x < edge.x2) and z < edge.z1 + ((x - edge.x1) / (edge.x2 - edge.x1)) * (edge.z2 - edge.z1) then
                    count = count + 1
                    -- if (yp < y1) != (yp < y2) and xp < x1 + ((yp-y1)/(y2-y1))*(x2-x1) then
                    --     count = count + 1
                end
            end
            return count % 2 == 1
        end
        return isInComplexPolygon(polygon, x, z)
    end

    --- takes a list of units and returns all the units that are in any of the zones
    ---@param unit_names table unit names
    ---@param zone_names table zone names
    ---@return table unit list of objects { unit = UNIT, zone_name = zoneName}
    function DCS_UTIL.getUnitsInZones(unit_names, zone_names)
        local units = {}
        local zones = {}

        for k = 1, #unit_names do
            local unit = Unit.getByName(unit_names[k]) or StaticObject.getByName(unit_names[k])
            if unit and unit:isExist() == true then
                units[#units + 1] = unit
            end
        end

        for index, zone_name in pairs(zone_names) do
            local zone = DCS_UTIL.__trigger_zones[zone_name]
            if zone then
                zones[#zones + 1] = zone
            end
        end

        local in_zone_units = {}
        for units_ind = 1, #units do
            local lUnit = units[units_ind]
            local unit_pos = lUnit:getPosition().p
            local lCat = Object.getCategory(lUnit)
            for zone_name, zone in pairs(zones) do
                if unit_pos and ((lCat == 1 and lUnit:isActive() == true) or lCat ~= 1) then -- it is a unit and is active or it is not a unit
                    if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                        if DCS_UTIL.IsPointInPolygon(zone.verts, unit_pos.x, unit_pos.z) == true then
                            in_zone_units[#in_zone_units + 1] = { unit = lUnit, zone_name = zone.name }
                        end
                    else
                        if (((unit_pos.x - zone.x) ^ 2 + (unit_pos.z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                            in_zone_units[#in_zone_units + 1] = { unit = lUnit, zone_name = zone.name }
                        end
                    end
                end
            end
        end
        return in_zone_units
    end

    --- takes a list of groups and returns all the group leaders that are in any of the zones
    ---@param group_names table unit names
    ---@param zone_name string zone names
    ---@return table groupnames list of group names
    function DCS_UTIL.getGroupsInZone(group_names, zone_name)
        local zone = DCS_UTIL.__trigger_zones[zone_name]
        if zone == nil then
            return {}
        end

        -- MAP Just for mapping sake
        local custom_zone = {
            x = zone.x,
            z = zone.z,
            zone_type = zone.zone_type,
            radius = zone.radius,
            verts = zone.verts
        }

        return DCS_UTIL.areGroupsInCustomZone(group_names, custom_zone)
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param group_names table North South position
    ---@param zone table { x, z, zonetype,  radius, verts }
    ---@return table groupnames list of groups that are in the zone
    function DCS_UTIL.areGroupsInCustomZone(group_names, zone)
        local units = {}
        if Spearhead.Util.tableLength(group_names) < 1 then return {} end

        for k = 1, #group_names do
            local entry = nil
            local group = Group.getByName(group_names[k])
            if group ~= nil then
                entry = { unit = group:getUnit(1), groupname = group_names[k] }
            else
                entry = { unit = StaticObject.getByName(group_names[k]), groupname = group_names[k] }
            end

            if entry and entry.unit and entry.unit:isExist() == true then
                units[#units + 1] = entry
            end
        end

        local result_groups = {}
        for _, entry in pairs(units) do
            local pos = entry.unit:getPoint()
            if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                if DCS_UTIL.IsPointInPolygon(zone.verts, pos.x, pos.z) == true then
                    table.insert(result_groups, entry.groupname)
                end
            else
                if (((pos.x - zone.x) ^ 2 + (pos.z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                    table.insert(result_groups, entry.groupname)
                end
            end
        end
        return result_groups
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone_names table zone names
    ---@return table zones list of objects { zone_name = zoneName}
    function DCS_UTIL.isPositionInZones(x, z, zone_names)
        local zones = {}
        for index, zone_name in pairs(zone_names) do
            local zone = DCS_UTIL.__trigger_zones[zone_name]
            if zone then
                zones[#zones + 1] = zone
            end
        end

        local result_zones = {}
        for zone_name, zone in pairs(zones) do
            if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                if DCS_UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                    result_zones[#result_zones + 1] = zone.name
                end
            else
                if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                    result_zones[#result_zones + 1] = zone.name
                end
            end
        end
        return result_zones
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone_name table zone names
    ---@return boolean result
    function DCS_UTIL.isPositionInZone(x, z, zone_name)
        local zone = DCS_UTIL.__trigger_zones[zone_name]
        if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
            if DCS_UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                return true
            end
        else
            if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                return true
            end
        end
        return false
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param zone_name string
    ---@param parent_zone_name string
    ---@return boolean result
    function DCS_UTIL.isZoneInZone(zone_name, parent_zone_name)
        local zoneA = DCS_UTIL.__trigger_zones[zone_name]
        local zoneB = DCS_UTIL.__trigger_zones[parent_zone_name]

        if zoneB.zone_type == DCS_UTIL.ZoneType.Polygon and zoneB.verts then
            if DCS_UTIL.IsPointInPolygon(zoneB.verts, zoneA.x, zoneA.z) == true then
                return true
            end
        else
            if (((zoneA.x - zoneB.x) ^ 2 + (zoneA.z - zoneB.z) ^ 2) ^ 0.5 <= zoneB.radius) then
                return true
            end
        end
        return false
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone table { x, z, zonetype,  radius }
    ---@return boolean result
    function DCS_UTIL.isPositionInCustomZone(x, z, zone)
        if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
            if DCS_UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                return true
            end
        else
            if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                return true
            end
        end
        return false
    end

    ---comment
    ---@param zone_name any
    ---@return table? zone { name,b zone_type, x, z, radius, verts }
    function DCS_UTIL.getZoneByName(zone_name)
        if zone_name == nil then return nil end
        return DCS_UTIL.__trigger_zones[zone_name]
    end

    ---maps the category name to the DCS group category
    ---@param input string the name
    ---@return integer?
    function DCS_UTIL.stringToGroupCategory(input)
        input = string.lower(input)
        if input == 'airplane' or input == 'plane' then
            return DCS_UTIL.GroupCategory.AIRPLANE
        end
        if input == 'helicopter' then
            return DCS_UTIL.GroupCategory.HELICOPTER
        end
        if input == 'ground' or input == 'vehicle' then
            return DCS_UTIL.GroupCategory.GROUND
        end
        if input == 'ship' then
            return DCS_UTIL.GroupCategory.SHIP
        end
        if input == 'train' then
            return DCS_UTIL.GroupCategory.TRAIN
        end
        if input == "static" then
            return DCS_UTIL.GroupCategory.STATIC
        end
        return nil;
    end

    --- get the group config as per start of the mission
    --- group = {
    ---     category,
    ---     country_id,
    ---     group_template
    --- }
    ---@param groupname string groupName you're looking for
    function DCS_UTIL.GetMizGroupOrDefault(groupname, default)
        local group = DCS_UTIL.__miz_groups[groupname]
        if group == nil then
            return default
        end
        return group
    end

    ---comment Get all group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllGroupNames()
        return DCS_UTIL.__groupNames
    end

    ---comment Get all BLUE group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllBlueGroupNames()
        return DCS_UTIL.__blueGroupNames
    end

    ---comment Get all RED group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllRedGroupNames()
        return DCS_UTIL.__redGroupNames
    end

    ---comment Get all units that are players
    ---@return table units
    function DCS_UTIL.getAllPlayerUnits()
        local units = {}
        for key, value in pairs({ 1, 2, 3 }) do
            local players = coalition.getPlayers(value)
            for key, unit in pairs(players) do
                units[#units + 1] = unit
            end
        end
        return units
    end

    ---get base name from ID
    ---@param baseId number
    ---@return string? name
    function DCS_UTIL.getAirbaseName(baseId)
        local stringified = tostring(baseId)
        return DCS_UTIL.__airbaseNamesById[stringified]
    end

    ---get base from id
    ---@param baseId number
    ---@return table? table
    function DCS_UTIL.getAirbaseById(baseId)
        local name = DCS_UTIL.getAirbaseName(baseId)
        if name == nil then return nil end
        return Airbase.getByName(name)
    end

    ---Get the starting coalition of a farp or airbase
    ---@return number? coalition
    function DCS_UTIL.getStartingCoalition(baseId)
        if baseId == nil then
            return nil
        end

        --STRING based dictionary otherwise it'll be a string/collapsed array
        baseId = tostring(baseId) or "nil"

        local result = DCS_UTIL.__airportsStartingCoalition[baseId]
        if result == nil then
            result = DCS_UTIL.__warehouseStartingCoalition[baseId]
        end
        return result
    end

    ---Gets all groups that have players
    ---@return table groups
    function DCS_UTIL.getAllPlayerGroups()
        local groupNames = {}
        local result = {}
        for key, value in pairs({ 1, 2, 3 }) do
            local players = coalition.getPlayers(value)
            for key, unit in pairs(players) do
                local group = unit:getGroup()
                if group ~= nil then
                    local name = group:getName()
                    if name ~= nil then
                        if groupNames[name] ~= nil then
                            groupNames[name] = 1
                            table.insert(result, group)
                        end
                    end
                end
            end
        end
        return result
    end

    --- spawns the units as specified in the mission file itself
    --- location and route can be nil and will then use default route
    ---@param groupName string
    ---@param location table? vector 3 data. { x , z, alt }
    ---@param route table? route of the group. If nil wil be the default route.
    ---@param uncontrolled boolean? Sets the group to be uncontrolled on spawn
    ---@return table? new_group the Group class that was spawned
    function DCS_UTIL.SpawnGroupTemplate(groupName, location, route, uncontrolled)
        if groupName == nil then
            return
        end

        local template = DCS_UTIL.GetMizGroupOrDefault(groupName, nil)
        if template == nil then
            return nil
        end
        if template.category == DCS_UTIL.GroupCategory.STATIC then
            --TODO: Implement location and route stuff
            local spawn_template = template.group_template
            coalition.addStaticObject(template.country_id, spawn_template)
        else
            local spawn_template = template.group_template
            if location ~= nil then
                local x_offset
                if location.x ~= nil then x_offset = spawn_template.x - location.x end

                local y_offset
                if location.z ~= nil then y_offset = spawn_template.y - location.z end

                spawn_template.x = location.x
                spawn_template.y = location.z

                for i, unit in pairs(spawn_template.units) do
                    unit.x = unit.x - x_offset
                    unit.y = unit.y - y_offset
                    unit.alt = location.alt
                end
            end

            if route ~= nil then
                spawn_template.route = route
            end

            if uncontrolled ~= nil then
                spawn_template.uncontrolled = uncontrolled
            end
            local new_group = coalition.addGroup(template.country_id, template.category, spawn_template)
            return new_group
        end
    end

    function DCS_UTIL.IsBingoFuel(groupName, offset)
        if offset == nil then offset = 0 end
        local bingoSetting = 0.20
        bingoSetting = bingoSetting + offset

        local group = Group.getByName(groupName)
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() == true and unit:inAir() == true and unit:getFuel() < bingoSetting then
                return true
            end
        end
        return false
    end

    DCS_UTIL.__INIT();
end
Spearhead.DcsUtil = DCS_UTIL

local LOGGER = {}
do
    LOGGER.LogLevelOptions = {
        DEBUG = 0,
        INFO = 1,
        WARN = 2,
        ERROR = 3,
        NONE = 4
    }

    local PreFix = "Spearhead"

    function LOGGER:new(logger_name, logLevel, liveLoggingLevel)
        local o = {}
        setmetatable(o, { __index = self })
        o.LoggerName = logger_name or "(loggername not set)"
        o.LogLevel = logLevel or LOGGER.LogLevelOptions.INFO
        o.LiveLoggingLevel = liveLoggingLevel or LOGGER.LogLevelOptions.NONE

        ---comment
        ---@param self table self logger
        ---@param message any the message
        o.info = function(self, message)
            if message == nil then
                return
            end
            message = UTIL.toString(message)

            if self.LogLevel <= LOGGER.LogLevelOptions.INFO then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end

            if self.LiveLoggingLevel <= LOGGER.LogLevelOptions.INFO then
                trigger.action.outText(message, 20)
            end
        end

        ---comment
        ---@param message string
        o.warn = function(self, message)
            if message == nil then
                return
            end
            message = UTIL.toString(message)

            if self.LogLevel <= LOGGER.LogLevelOptions.WARN then
                env.warning("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end

            if self.LiveLoggingLevel <= LOGGER.LogLevelOptions.WARN then
                trigger.action.outText(message, 20)
            end
        end

        ---comment
        ---@param self table -- logger
        ---@param message any -- the message
        o.error = function(self, message)
            if message == nil then
                return
            end

            message = UTIL.toString(message)

            if self.LogLevel <= LOGGER.LogLevelOptions.ERROR then
                env.error("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end

            if self.LiveLoggingLevel <= LOGGER.LogLevelOptions.ERROR then
                trigger.action.outText(message, 20)
            end
        end

        ---write debug
        ---@param self table
        ---@param message any the message
        o.debug = function(self, message)
            if message == nil then
                return
            end

            message = UTIL.toString(message)
            if self.LogLevel <= LOGGER.LogLevelOptions.DEBUG then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "][DEBUG] " .. message)
            end

            if self.LiveLoggingLevel <= LOGGER.LogLevelOptions.DEBUG then
                trigger.action.outText(message, 20)
            end
        end


        return o
    end
end
Spearhead.LoggerTemplate = LOGGER

local ROUTE_UTIL = {}
do --setup route util
    ---comment
    ---@param attackHelos boolean
    ---@return table
    local function GetCAPTargetTypes(attackHelos)
        local targetTypes = {
            [1] = "Fighters",
            [2] = "Multirole fighters",
            [3] = "Bombers",
        }

        if attackHelos then
            targetTypes[4] = "Helicopters"
        end

        return targetTypes
    end

    ---comment
    ---@param airdromeId number
    ---@param basePoint table { x, z, y } (y == alt)
    ---@param speed number the speed
    ---@return table task
    local RtbTask = function(airdromeId, basePoint, speed)
        if basePoint == nil then
            basePoint = Spearhead.Util.getAirbaseById(airdromeId):getPoint()
        end

        return {
            alt = basePoint.y,
            action = "Landing",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = basePoint.x,
            y = basePoint.z,
            speed_locked = true,
            formation_template = "",
            airdromeId = airdromeId,
            type = "Land",
            task = {
                id = "ComboTask",
                params = {
                    tasks = {}
                }
            }
        }
    end

    ---comment
    ---@param groupName string
    ---@param position table { x, y}
    ---@param altitude number
    ---@param speed number
    ---@param duration number
    ---@param engageHelos boolean
    ---@param pattern string ["Race-Track"|"Circle"]
    ---@return table
    local CapTask = function(groupName, position, altitude, speed, duration, engageHelos, deviationdistance, pattern)
        local durationBefore10 = duration - 600
        if durationBefore10 < 0 then durationBefore10 = 0 end
        local durationAfter10 = 600
        if duration < 600 then
            durationAfter10 = duration
        end

        return {
            alt = altitude,
            action = "Turning Point",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = position.x,
            y = position.z,
            speed_locked = true,
            formation_template = "",
            task = {
                id = "ComboTask",
                params = {
                    tasks = {
                        [1] = {
                            number = 1,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishOnStation, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        },
                        [2] = {
                            id = 'EngageTargets',
                            params = {
                                maxDist = deviationdistance,
                                maxDistEnabled = deviationdistance >= 0, -- required to check maxDist
                                targetTypes = GetCAPTargetTypes(engageHelos),
                                priority = 0
                            }
                        },
                        [3] = {
                            number = 3,
                            auto = false,
                            id = "ControlledTask",
                            enabled = true,
                            params = {
                                task = {
                                    id = "Orbit",
                                    params = {
                                        altitude = altitude,
                                        pattern = pattern,
                                        speed = speed,
                                    }
                                },
                                stopCondition = {
                                    duration = durationBefore10,
                                    condition = "return Spearhead.DcsUtil.IsBingoFuel(\"" .. groupName .. "\", 0.10)",
                                }
                            }
                        },
                        [4] = {
                            number = 4,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishRTBInTen, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        },
                        [5] = {
                            number = 5,
                            auto = false,
                            id = "ControlledTask",
                            enabled = true,
                            params = {
                                task = {
                                    id = "Orbit",
                                    params = {
                                        altitude = altitude,
                                        pattern = pattern,
                                        speed = speed,
                                    }
                                },
                                stopCondition = {
                                    duration = durationAfter10,
                                    condition = "return Spearhead.DcsUtil.IsBingoFuel(\"" .. groupName .. "\")",
                                }
                            }
                        },
                        [6] = {
                            number = 6,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishRTB, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    end

    ---comment
    ---@param position table { x, y}
    ---@param altitude number
    ---@param speed number
    ---@param childTasks table
    ---@return table
    local FlyToPointTask = function(position, altitude, speed, childTasks)
        return {
            alt = altitude,
            action = "Turning Point",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = position.x,
            y = position.z,
            speed_locked = true,
            formation_template = "",
            task = {
                id = "ComboTask",
                params = {
                    tasks = childTasks or {}
                }
            }
        }
    end

    ---comment
    ---@param groupName string groupName you're creating this route for
    ---@param airdromeId number airdromeId
    ---@param capPoint table { x, z }
    ---@param altitude number
    ---@param speed number
    ---@param durationOnStation number
    ---@param attackHelos boolean
    ---@param deviationDistance number
    ---@return table route
    ROUTE_UTIL.createCapMission = function(groupName, airdromeId, capPoint, racetrackSecondPoint, altitude, speed,
                                           durationOnStation, attackHelos, deviationDistance)
        local baseName = Spearhead.DcsUtil.getAirbaseName(airdromeId)
        if baseName == nil then
            return {}
        end

        durationOnStation = durationOnStation or 1800
        altitude = altitude or 3000
        speed = speed or 130
        attackHelos = attackHelos or false
        deviationDistance = deviationDistance or 32186

        local base = Airbase.getByName(baseName)
        if base == nil then
            return {}
        end

        local additionalFlyOverTasks = {
            {
                enabled = true,
                auto = false,
                id = "WrappedAction",
                number = 1,
                params = {
                    action = {
                        id = "Option",
                        params = {
                            variantIndex = 2,
                            name = AI.Option.Air.id.FORMATION,
                            formationIndex = 2,
                            value = 131074
                        }
                    }
                }
            }
        }

        local orbitType = "Circle"
        if racetrackSecondPoint then orbitType = "Race-Track" end

        local basePoint = base:getPoint()
        local points = {}
        if racetrackSecondPoint == nil then
            points = {
                [1] = FlyToPointTask(capPoint, altitude, speed, additionalFlyOverTasks),
                [2] = CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = RtbTask(airdromeId, basePoint, speed)
            }
        else
            points = {
                [1] = FlyToPointTask(capPoint, altitude, speed, additionalFlyOverTasks),
                [2] = CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = FlyToPointTask(racetrackSecondPoint, altitude, speed, {}),
                [4] = RtbTask(airdromeId, basePoint, speed)
            }
        end

        return {
            id = 'Mission',
            params = {
                airborne = true,
                route = {
                    points = points
                }
            }
        }
    end

    ---Creates an RTB task. The first point is to trigger the TDCS OnRTB Event, the second task will be the actual RTB point
    ---If any of the values are not met it will return nil
    ---@param groupName string
    ---@param airdromeId number
    ---@param speed number
    ---@return table?, string ComboTask
    ROUTE_UTIL.CreateRTBMission = function(groupName, airdromeId, speed)
        --[[
            TODO: Test the creation and pubishing of event and the timing of said event
        ]] --

        local base = Spearhead.DcsUtil.getAirbaseById(airdromeId)
        if base == nil then
            return nil, "No airbase found for ID " .. tostring(airdromeId)
        end

        local group = Group.getByName(groupName)
        local pos;
        local i = 1
        local units = group:getUnits()
        while pos == nil and i <= Spearhead.Util.tableLength(units) do
            local unit = units[i]
            if unit and unit:isExist() == true and unit:inAir() == true then
                pos = unit:getPoint()
            end
            i = i + 1
        end

        speed = speed or 130
        if pos == nil then
            return nil, "Could not find any unit in the air to set the RTB task"
        end

        local additionalFlyOverTasks = {
            {
                enabled = true,
                auto = false,
                id = "WrappedAction",
                number = 1,
                params = {
                    action = {
                        id = "Option",
                        params = {
                            variantIndex = 2,
                            name = AI.Option.Air.id.FORMATION,
                            formationIndex = 2,
                            value = 131074
                        }
                    }
                }
            }
        }

        return {
            id = "Mission",
            params = {
                airborne = true, -- RTB mission generally are given to airborne units
                route = {
                    points = {

                        [1] = {
                            alt = pos.y,
                            action = "Turning Point",
                            alt_type = "BARO",
                            speed = speed,
                            ETA = 0,
                            ETA_locked = false,
                            x = pos.x,
                            y = pos.z,
                            speed_locked = true,
                            formation_template = "",
                            task = {
                                id = "ComboTask",
                                params = {
                                    tasks = {
                                        [1] = {
                                            number = 1,
                                            auto = false,
                                            id = "WrappedAction",
                                            enabled = "true",
                                            params = {
                                                action = {
                                                    id = "Script",
                                                    params = {
                                                        command = "pcall(Spearhead.Events.PublishRTB, \"" ..
                                                            groupName .. "\")"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        [2] = FlyToPointTask(base:getPoint(), 600, speed, additionalFlyOverTasks),
                        [3] = RtbTask(airdromeId, base:getPoint(), speed)
                    }
                }
            }
        }, ""
    end

    ROUTE_UTIL.CreateCarrierRacetrack = function(pointA, pointB)
        return {
            id = "Mission",
            params = {
                airborne = false,
                route = {
                    points = {
                        [1] =
                        {
                            ["alt"] = -0,
                            ["type"] = "Turning Point",
                            ["ETA"] = 0,
                            ["alt_type"] = "BARO",
                            ["formation_template"] = "",
                            ["y"] = pointA.z,
                            ["x"] = pointA.x,
                            ["ETA_locked"] = false,
                            ["speed"] = 13.88888,
                            ["action"] = "Turning Point",
                            ["task"] =
                            {
                                ["id"] = "ComboTask",
                                ["params"] =
                                {
                                    ["tasks"] = {},
                                }, -- end of ["params"]
                            }, -- end of ["task"]
                            ["speed_locked"] = true,
                        },
                        [2] =
                        {
                            ["alt"] = -0,
                            ["type"] = "Turning Point",
                            ["ETA"] = -0,
                            ["alt_type"] = "BARO",
                            ["formation_template"] = "",
                            ["y"] = pointB.z,
                            ["x"] = pointB.x,
                            ["ETA_locked"] = false,
                            ["speed"] = 13.88888,
                            ["action"] = "Turning Point",
                            ["task"] =
                            {
                                ["id"] = "ComboTask",
                                ["params"] =
                                {
                                    ["tasks"] =
                                    {
                                        [1] =
                                        {
                                            ["enabled"] = true,
                                            ["auto"] = false,
                                            ["id"] = "GoToWaypoint",
                                            ["number"] = 1,
                                            ["params"] =
                                            {
                                                ["fromWaypointIndex"] = 2,
                                                ["nWaypointIndx"] = 1,
                                            },
                                        },
                                    },
                                },
                            },
                            ["speed_locked"] = true,
                        }
                    }
                }
            }
        }, ""
    end
end

Spearhead.RouteUtil = ROUTE_UTIL

local SpearheadEvents = {}
do
    local SpearheadLogger = Spearhead.LoggerTemplate:new("Spearhead Events",
        Spearhead.LoggerTemplate.LogLevelOptions.INFO)

    do -- STAGE NUMBER CHANGED
        local OnStageNumberChangedListeners = {}
        local OnStageNumberChangedHandlers = {}

        ---Add a stage zone number changed listener
        ---@param listener table object with function OnStageNumberChanged(self, number)
        SpearheadEvents.AddStageNumberChangedListener = function(listener)
            if type(listener) ~= "table" then
                SpearheadLogger:warn("Event listener not of type table, did you mean to use handler?")
                return
            end
            table.insert(OnStageNumberChangedListeners, listener)
        end

        ---Add a stage zone number changed listener
        ---@param handler function function(number)
        SpearheadEvents.AddStageNumberChangedHandler = function(handler)
            if type(handler) ~= "function" then
                SpearheadLogger:warn("Event handler not of type function, did you mean to use listener?")
                return
            end
            table.insert(OnStageNumberChangedHandlers, handler)
        end

        ---@param newStageNumber number
        SpearheadEvents.PublishStageNumberChanged = function(newStageNumber)
            for _, callable in pairs(OnStageNumberChangedListeners) do
                local succ, err = pcall(function()
                    callable:OnStageNumberChanged(newStageNumber)
                end)
                if err then
                    SpearheadLogger:error(err)
                end
            end

            for _, callable in pairs(OnStageNumberChangedHandlers) do
                local succ, err = pcall(callable, newStageNumber)
                if err then
                    SpearheadLogger:error(err)
                end
            end
        end
    end

    local onLandEventListeners = {}
    ---Add an event listener to a specific unit
    ---@param unitName string to call when the unit lands
    ---@param landListener table table with function OnUnitLanded(self, initiatorUnit, airbase)
    SpearheadEvents.addOnUnitLandEventListener = function(unitName, landListener)
        if type(landListener) ~= "table" then
            SpearheadLogger:warn("Event handler not of type table/object")
            return
        end

        SpearheadLogger:debug("Added Land event handler for unit: " .. unitName)

        if onLandEventListeners[unitName] == nil then
            onLandEventListeners[unitName] = {}
        end
        table.insert(onLandEventListeners[unitName], landListener)
    end

    local OnUnitLostListeners = {}
    ---This listener gets fired for any event that can indicate a loss of a unit.
    ---Such as: Eject, Crash, Dead, Unit_Lost,
    ---@param unitName any
    ---@param unitLostListener table Object with function: OnUnitLost(initiatorUnit)
    SpearheadEvents.addOnUnitLostEventListener = function(unitName, unitLostListener)
        if type(unitLostListener) ~= "table" then
            SpearheadLogger:warn("Unit lost Event listener not of type table/object")
            return
        end

        if OnUnitLostListeners[unitName] == nil then
            OnUnitLostListeners[unitName] = {}
        end

        table.insert(OnUnitLostListeners[unitName], unitLostListener)
    end

    do -- ON RTB
        local OnGroupRTBListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTB(self, groupName)
        SpearheadEvents.addOnGroupRTBListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                SpearheadLogger:warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBListeners[groupName] == nil then
                OnGroupRTBListeners[groupName] = {}
            end

            table.insert(OnGroupRTBListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishRTB = function(groupName)
            SpearheadLogger:debug("Publishing RTB event for group " .. groupName)
            if groupName ~= nil then
                if OnGroupRTBListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTB(groupName)
                        end)
                        if err then
                            SpearheadLogger:error(err)
                        end
                    end
                end
            end
        end

        local OnGroupRTBInTenListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTBInTen(self, groupName)
        SpearheadEvents.addOnGroupRTBInTenListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                SpearheadLogger:warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBInTenListeners[groupName] == nil then
                OnGroupRTBInTenListeners[groupName] = {}
            end

            table.insert(OnGroupRTBInTenListeners[groupName], handlingObject)
        end

        ---Publish the Group is RTB
        ---@param groupName string
        SpearheadEvents.PublishRTBInTen = function(groupName)
            SpearheadLogger:debug("Publishing RTB in TEN event for group " .. groupName)
            if groupName ~= nil then
                if OnGroupRTBInTenListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBInTenListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTBInTen(groupName)
                        end)
                        if err then
                            SpearheadLogger:error(err)
                        end
                    end
                end
            end
        end
    end

    do -- ON Station
        local OnGroupOnStationListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        SpearheadEvents.addOnGroupOnStationListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                SpearheadLogger:warn("Event handler not of type table/object")
                return
            end

            if OnGroupOnStationListeners[groupName] == nil then
                OnGroupOnStationListeners[groupName] = {}
            end

            table.insert(OnGroupOnStationListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishOnStation = function(groupName)
            SpearheadLogger:debug("Publishing onStation event for group " .. groupName)
            if groupName ~= nil then
                if OnGroupOnStationListeners[groupName] then
                    for _, callable in pairs(OnGroupOnStationListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupOnStation(groupName)
                        end)
                        if err then
                            SpearheadLogger:error(err)
                        end
                    end
                end
            end
        end
    end

    do     --COMMANDS
        do -- status updates
            local onStatusRequestReceivedListeners = {}
            ---comment
            ---@param listener table object with OnStatusRequestReceived(self, groupId)
            SpearheadEvents.AddOnStatusRequestReceivedListener = function(listener)
                if type(listener) ~= "table" then
                    SpearheadLogger:warn("Unit lost Event listener not of type table/object")
                    return
                end

                table.insert(onStatusRequestReceivedListeners, listener)
            end

            local triggerStatusRequestReceived = function(groupId)
                for _, callable in pairs(onStatusRequestReceivedListeners) do
                    local succ, err = pcall(function()
                        callable:OnStatusRequestReceived(groupId)
                    end)
                end
            end

            SpearheadEvents.AddCommandsToGroup = function(groupId)
                local base = "MISSIONS"
                if groupId then
                    missionCommands.addCommandForGroup(groupId, "Stage Status", nil, triggerStatusRequestReceived,
                        groupId)
                end
            end

            --Single player purpose
            local id = net.get_my_player_id()
            if id == 0 then
                SpearheadLogger:info("Single Player detected")

                local unit = world.getPlayer()
                if unit then
                    local groupId = unit:getGroup():getID()
                    SpearheadEvents.AddCommandsToGroup(groupId)

                    --DEBUG COMMANDS
                    do
                        local activateStage = function(number)
                            SpearheadEvents.PublishStageNumberChanged(number)
                        end

                        missionCommands.addSubMenuForGroup(groupId, "debug", nil)
                        missionCommands.addSubMenuForGroup(groupId, "Set Stage", { "debug" })

                        for i = 0, 9 do
                            local menuName = tostring(i) .. ".."
                            missionCommands.addSubMenuForGroup(groupId, menuName, { "debug", "Set Stage" })
                            for ii = 0, 9 do
                                local number = tonumber(tostring(i) .. tostring(ii))
                                missionCommands.addCommandForGroup(groupId, "Stage " .. tostring(number),
                                { "debug", "Set Stage", menuName }, activateStage, number)
                            end
                        end
                    end
                end
            end
        end
    end

    do -- PLAYER ENTER UNIT
        local playerEnterUnitListeners = {}
        ---comment
        ---@param listener table object with OnPlayerEnterUnit(self, unit)
        SpearheadEvents.AddOnPlayerEnterUnitListener = function(listener)
            if type(listener) ~= "table" then
                SpearheadLogger:warn("Unit lost Event listener not of type table/object")
                return
            end

            table.insert(playerEnterUnitListeners, listener)
        end

        SpearheadEvents.TriggerPlayerEntersUnit = function(unit)
            if unit ~= nil then
                if playerEnterUnitListeners then
                    for _, callable in pairs(playerEnterUnitListeners) do
                        local succ, err = pcall(function()
                            callable:OnPlayerEnterUnit(unit)
                        end)
                        if err then
                            SpearheadLogger:error(err)
                        end
                    end
                end
            end
        end
    end

    local e = {}
    function e:onEvent(event)
        if event.id == world.event.S_EVENT_LAND or event.id == world.event.S_EVENT_RUNWAY_TOUCH then
            local unit = event.initiator
            local airbase = event.place
            if unit ~= nil then
                local name = unit:getName()
                if onLandEventListeners[name] then
                    for _, callable in pairs(onLandEventListeners[name]) do
                        local succ, err = pcall(function()
                            callable:OnUnitLanded(unit, airbase)
                        end)
                        if err then
                            SpearheadLogger:error(err)
                        end
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_DEAD or
            event.id == world.event.S_EVENT_CRASH or
            event.id == world.event.S_EVENT_EJECTION or
            event.id == world.event.S_EVENT_UNIT_LOST then
            local object = event.initiator
            if object and object.getName and OnUnitLostListeners[object:getName()] then
                for _, callable in pairs(OnUnitLostListeners[object:getName()]) do
                    local succ, err = pcall(function()
                        callable:OnUnitLost(object)
                    end)

                    if err then
                        SpearheadLogger:error(err)
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
            env.info("blaat player entering unit")
            local groupId = event.initiator:getGroup():getID()
            SpearheadEvents.AddCommandsToGroup(groupId)
        end
    end

    world.addEventHandler(e)
end
Spearhead.Events = SpearheadEvents

Spearhead.MissionEditingWarnings = {}
function Spearhead.AddMissionEditorWarning(warningMessage)
    table.insert(Spearhead.MissionEditingWarnings, warningMessage or "skip")
end

missionCommands.addSubMenu("Missions")

local loadDone = false
Spearhead.LoadingDone = function()
    if loadDone == true then
        return
    end

    local warningLogger = Spearhead.LoggerTemplate:new("MISSIONPARSER", Spearhead.LoggerTemplate.LogLevelOptions.INFO, 4)
    if Spearhead.Util.tableLength(Spearhead.MissionEditingWarnings) > 0 then
        for key, message in pairs(Spearhead.MissionEditingWarnings) do
            warningLogger:warn(message)
        end
    else
        warningLogger:info("No issues detected")
    end

    loadDone = true
end
