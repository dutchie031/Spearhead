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
    ---@param list Array
    ---@return any @random element from the list
    function UTIL.randomFromList(list)
        local max = #list

        if max == 0 or max == nil then
            return nil
        end

        local random = math.random(0, max)
        if random == 0 then random = 1 end

        return list[random]
    end

    ---@param str string
    ---@param find string
    ---@param replace string
    ---@return string
    function UTIL.replaceString(str, find, replace)
        if str == nil then return "" end
        if find == nil or replace == nil then return str end

        local result = str:gsub(find, replace)
        return result
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
    ---@param ignoreCase boolean?
    ---@return boolean
    UTIL.startswith = function(str, findable, ignoreCase)
        if ignoreCase == true then
            return string.lower(str):find('^' .. string.lower(findable)) ~= nil
        end

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

    ---comment
    ---@param a Vec2
    ---@param b Vec2
    ---@return number
    function UTIL.VectorDistance2d(a, b)
        return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    end

    ---comment
    ---@param a Vec3
    ---@param b Vec3
    ---@return number
    function UTIL.VectorDistance3d(a, b)
        return UTIL.vectorMagnitude({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z })
    end

    ---comment
    ---@param vec Vec3
    ---@return number
    function UTIL.vectorMagnitude(vec)
        return (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
    end

    local function isInComplexPolygon(polygon, x, y)
        local function getEdges(poly)
            local result = {}
            for i = 1, #poly do
                local point1 = poly[i]
                local point2Index = i + 1
                if point2Index > #poly then point2Index = 1 end
                local point2 = poly[point2Index]
                local edge = { x1 = point1.x, z1 = point1.y, x2 = point2.x, z2 = point2.y }
                table.insert(result, edge)
            end
            return result
        end

        local edges = getEdges(polygon)
        local count = 0;
        for _, edge in pairs(edges) do
            if (x < edge.x1) ~= (x < edge.x2) and y < edge.z1 + ((x - edge.x1) / (edge.x2 - edge.x1)) * (edge.z2 - edge.z1) then
                count = count + 1
                -- if (yp < y1) != (yp < y2) and xp < x1 + ((yp-y1)/(y2-y1))*(x2-x1) then
                --     count = count + 1
            end
        end
        return count % 2 == 1
    end

    ---comment
    ---@param polygon Array<Vec2> of pairs { x, y }
    ---@param x number X location
    ---@param y number Y location
    ---@return boolean
    function UTIL.IsPointInPolygon(polygon, x, y)
        return isInComplexPolygon(polygon, x, y)
    end

    ---@param point Vec3
    ---@param zone SpearheadTriggerZone
    function UTIL.is3dPointInZone(point, zone)
        if zone.zone_type == "Polygon" and zone.verts then
            if UTIL.IsPointInPolygon(zone.verts, point.x, point.z) == true then
                return true
            end
        else
            if (((point.x - zone.location.x) ^ 2 + (point.z - zone.location.y) ^ 2) ^ 0.5 <= zone.radius) then
                return true
            end
        end

        return false
    end

    ---comment
    ---@param points Array<Vec2> points 
    ---@return Array<Vec2> hullPoints
    function UTIL.getConvexHull(points)
        if #points == 0 then
            return {}
        end

        ---comment
        ---@param a Vec2
        ---@param b Vec2
        ---@param c Vec2
        ---@return boolean
        local function ccw(a, b, c)
            return (b.y - a.y) * (c.x - a.x) > (b.x - a.x) * (c.y - a.y)
        end

        table.sort(points, function(left, right)
            return left.y < right.y
        end)

        local hull = {}
        -- lower hull
        for _, point in pairs(points) do
            while #hull >= 2 and not ccw(hull[#hull - 1], hull[#hull], point) do
                table.remove(hull, #hull)
            end
            table.insert(hull, point)
        end

        -- upper hull
        local t = #hull + 1
        for i = #points, 1, -1 do
            local point = points[i]
            while #hull >= t and not ccw(hull[#hull - 1], hull[#hull], point) do
                table.remove(hull, #hull)
            end
            table.insert(hull, point)
        end
        table.remove(hull, #hull)
        return hull
    end

    ---@param points Array<Vec2>
    function UTIL.enlargeConvexHull(points, meters)
        ---@type Array<Vec2>
        local allpoints = {}

        for _, point in pairs(points) do
            table.insert(allpoints, point)

            allpoints[#allpoints + 1] = point
            allpoints[#allpoints+1] = { x = point.x + meters, y = point.y, }
            allpoints[#allpoints+1] = { x = point.x - meters, y = point.y, }
            allpoints[#allpoints+1] = { x = point.x, y = point.y + meters, }
            allpoints[#allpoints+1] = { x = point.x, y = point.y - meters, }

            allpoints[#allpoints+1] = { x = point.x + math.cos(math.rad(45)) * meters, y = point.y + math.sin(math.rad(45)) * meters, }
            allpoints[#allpoints+1] = { x = point.x - math.cos(math.rad(45)) * meters, y = point.y - math.sin(math.rad(45)) * meters, }
            allpoints[#allpoints+1] = { x = point.x - math.cos(math.rad(45)) * meters, y = point.y + math.sin(math.rad(45)) * meters, }
            allpoints[#allpoints+1] = { x = point.x + math.cos(math.rad(45)) * meters, y = point.y - math.sin(math.rad(45)) * meters, }
        end

        return UTIL.getConvexHull(allpoints)
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
                y,
                radius
                verts,

            }
        ]] --

        ---@alias SpearheadTriggerZoneType
        ---| "Cilinder"
        ---| "Polygon"

        ---@class SpearheadTriggerZone
        ---@field name string
        ---@field location Vec2
        ---@field radius number
        ---@field verts Array<Vec2>
        ---@field zone_type SpearheadTriggerZoneType

        ---@type Array<SpearheadTriggerZone>
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

    ---@type table<string, SpearheadTriggerZone>
    DCS_UTIL.__airbaseZonesByName = {}

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

                                        local skippable = false

                                        if category_id == DCS_UTIL.GroupCategory.STATIC then
                                            local unit = group.units[1]

                                            if unit.category == "Heliports" then
                                                skippable = true
                                            end

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

                                        if skippable == false then
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
            end

            do --init trigger zones
                for i, trigger_zone in pairs(env.mission.triggers.zones) do
                    -- reorder verts as they are not ordered correctly in the ME
                    local verts = {}
                    if Spearhead.Util.tableLength(trigger_zone.verticies) >= 4 then
                        table.insert(verts, { x = trigger_zone.verticies[4].x, y = trigger_zone.verticies[4].y })
                        table.insert(verts, { x = trigger_zone.verticies[3].x, y = trigger_zone.verticies[3].y })
                        table.insert(verts, { x = trigger_zone.verticies[2].x, y = trigger_zone.verticies[2].y })
                        table.insert(verts, { x = trigger_zone.verticies[1].x, y = trigger_zone.verticies[1].y })
                    end

                    local zoneType = "Cilinder"
                    if trigger_zone.type == DCS_UTIL.ZoneType.Polygon then
                        zoneType = "Polygon"
                    end

                    ---@type SpearheadTriggerZone
                    local zone = {
                        name = trigger_zone.name,
                        zone_type = zoneType,
                        location = { x = trigger_zone.x, y = trigger_zone.y },
                        radius = trigger_zone.radius,
                        verts = verts
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

            do -- fill airbaseNames and zones
                local airbases = world.getAirbases()
                if airbases then
                    for _, airbase in pairs(airbases) do
                        local name = airbase:getName()

                        airbase:autoCapture(false)

                        DCS_UTIL.__airbaseNamesById[tostring(airbase:getID())] = name

                        if name  then
                            local relevantPoints = {}
                            for _, x in pairs(airbase:getRunways()) do
                                if x.position and x.position.x and x.position.z then
                                    table.insert(relevantPoints, { x = x.position.x, z = x.position.z, y = 0 })
                                end
                            end

                            for _, x in pairs(airbase:getParking()) do
                                if x.vTerminalPos and x.vTerminalPos.x and x.vTerminalPos.z then
                                    table.insert(relevantPoints, { x = x.vTerminalPos.x, z = x.vTerminalPos.z, y = 0 })
                                end
                            end

                            local points = UTIL.getConvexHull(relevantPoints)
                            local enlargedPoints = UTIL.enlargeConvexHull(points, 750)

                            DCS_UTIL.__airbaseZonesByName[name] = {
                                name = name,
                                location = { x = airbase:getPoint().x, y = airbase:getPoint().z },
                                zone_type = "Polygon",
                                radius = 0,
                                verts = enlargedPoints
                            }
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
        if DCS_UTIL.__miz_groups[groupName] then
            return DCS_UTIL.__miz_groups[groupName].category == 5;
        end

        return StaticObject.getByName(groupName) ~= nil
    end

    ---destroy the given group
    ---@param groupName string
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

    ---destroy the given unit
    function DCS_UTIL.DestroyUnit(unitName)
        if DCS_UTIL.IsGroupStatic(unitName) == true then
            local object = StaticObject.getByName(unitName)
            if object ~= nil then
                object:destroy()
            end
        else
            local unit = Unit.getByName(unitName)
            if unit and unit:isExist() then
                unit:destroy()
            end
        end
    end

    --- takes a list of units and returns all the units that are in any of the zones
    ---@param unit_names table unit names
    ---@param zone_names table zone names
    ---@return table unit list of objects { unit = UNIT, zone_name = zoneName}
    function DCS_UTIL.getUnitsInZones(unit_names, zone_names)
        local units = {}

        ---@type Array<SpearheadTriggerZone>
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
                    local isInZone = UTIL.is3dPointInZone(unit_pos, zone)
                    if isInZone == true then
                        in_zone_units[#in_zone_units + 1] = { unit = lUnit, zone_name = zone.name }
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

        return DCS_UTIL.areGroupsInCustomZone(group_names, zone)
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param group_names Array<string> North South position
    ---@param zone SpearheadTriggerZone
    ---@return Array<string> groupnames list of groups that are in the zone
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
            local isInZone = UTIL.is3dPointInZone(pos, zone)
            if isInZone == true then
                table.insert(result_groups, entry.groupname)
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
        ---@type Array<SpearheadTriggerZone>
        local zones = {}
        for index, zone_name in pairs(zone_names) do
            local zone = DCS_UTIL.__trigger_zones[zone_name]
            if zone then
                zones[#zones + 1] = zone
            end
        end

        local result_zones = {}
        for zone_name, zone in pairs(zones) do
            if UTIL.is3dPointInZone({ x = x, z = z, y = 0 }, zone) == true then
                result_zones[#result_zones + 1] = zone.name
            end
        end
        return result_zones
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone_name string zone name
    ---@return boolean result
    function DCS_UTIL.isPositionInZone(x, z, zone_name)
        local zone = DCS_UTIL.__trigger_zones[zone_name]
        if UTIL.is3dPointInZone({ x = x, y = 0, z = z }, zone) then
            return true
        end
        return false
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param zone_name string
    ---@param parent_zone_name string
    ---@return boolean result
    function DCS_UTIL.isZoneInZone(zone_name, parent_zone_name)
        local zoneA = DCS_UTIL.__trigger_zones[zone_name] --[[@as SpearheadTriggerZone]]
        if zoneA == nil then return false end
        local zoneB = DCS_UTIL.__trigger_zones[parent_zone_name] --[[@as SpearheadTriggerZone]]
        if zoneB == nil then return false end
        return UTIL.is3dPointInZone({ x = zoneA.location.x, y = 0, z = zoneA.location.y }, zoneB)
    end

    ---comment
    ---@param zone_name any
    ---@return SpearheadTriggerZone? zone { name,b zone_type, x, z, radius, verts }
    function DCS_UTIL.getZoneByName(zone_name)
        if zone_name == nil then return nil end
        return DCS_UTIL.__trigger_zones[zone_name]
    end

    ---comment
    ---@param airbaseName string
    ---@return SpearheadTriggerZone? zone { name,b zone_type, x, z, radius, verts }
    function DCS_UTIL.getAirbaseZoneByName(airbaseName)
        if string == nil then return nil end
        return DCS_UTIL.__airbaseZonesByName[string]
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

    ---@param location Vec2
    ---@param unitType string
    function DCS_UTIL.convertVec2ToUnitUsableType(location, unitType)

        local height = land.getHeight(location)
        local vec3 = { x = location.x, y = height, z = location.y }

        if unitType == "AH-64D_BLK_II" then
            return DCS_UTIL.convertToDisplayCoord(vec3, "MGRS")
        end

        return DCS_UTIL.convertToDisplayCoord(vec3, "DDM")
    end

    ---@alias CoordType
    ---| "MGRS"
    ---| "DDM"

    ---@param location Vec3
    ---@param coordType CoordType
    function DCS_UTIL.convertToDisplayCoord(location, coordType)
        local lattitude, longitude, altitude = coord.LOtoLL(location)

        if coordType == "MGRS" then
            local mgrs = coord.LLtoMGRS(lattitude, longitude)
            return string.format("%s %s %s %s", mgrs.UTMZone, mgrs.MGRSDigraph, mgrs.Northing, mgrs.Easting)
        end

        -- Convert DD to DDM (Degrees Decimal Minutes)
        local function dd_to_ddm(dd)
            local degrees = math.floor(math.abs(dd))
            local minutes = (math.abs(dd) - degrees) * 60
            local sign = dd >= 0 and 1 or -1
            return degrees * sign, minutes
        end

        local lat_deg, lat_min = dd_to_ddm(lattitude)
        local lon_deg, lon_min = dd_to_ddm(longitude)

        local lat_hemisphere = lattitude >= 0 and "N" or "S"
        local lon_hemisphere = longitude >= 0 and "E" or "W"

        return string.format("%d° %.3f' %s %d° %.3f' %s %d ft",
            math.abs(lat_deg), lat_min, lat_hemisphere,
            math.abs(lon_deg), lon_min, lon_hemisphere,
            altitude * 3,28084)
    end

    ---@param group Group
    function DCS_UTIL.getUnitTypeFromGroup(group)
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() then
                return unit:getTypeName()
            end
        end
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
    ---@return Array<Unit> units
    function DCS_UTIL.getAllPlayerUnits()
        local units = {}
        for i = 0, 2 do
            local players = coalition.getPlayers(i)
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
    ---@return Airbase? table
    function DCS_UTIL.getAirbaseById(baseId)
        local name = DCS_UTIL.getAirbaseName(baseId)
        if name == nil then return nil end
        return Airbase.getByName(name)
    end

    ---Get the starting coalition of a farp or airbase
    ---@param airbase Airbase
    ---@return number? coalition
    function DCS_UTIL.getStartingCoalition(airbase)
        if airbase == nil then
            return nil
        end

        --STRING based dictionary otherwise it'll be a string/collapsed array
        local baseId = tostring(airbase:getID())

        local result = DCS_UTIL.__airportsStartingCoalition[baseId]
        if result == nil then
            result = DCS_UTIL.__warehouseStartingCoalition[baseId]
        end
        return result
    end

    ---Spawn an corpse
    ---@param countryId number countryId
    ---@param unitType string
    ---@param location table { z, y, z}
    ---@param heading number
    function DCS_UTIL.SpawnCorpse(countryId, unitName, unitType, location, heading)
        local name = "dead_" .. unitName

        local staticObj = {
            ["heading"] = heading,
            --["shape_name"] = "stolovaya",
            ["type"] = unitType,
            ["name"] = name,
            ["y"] = location.z,
            ["x"] = location.x,
            ["dead"] = true,
        }

        coalition.addStaticObject(countryId, staticObj)
    end

    function DCS_UTIL.CleanCorpse(unitName)
        local unitName = "dead_" .. unitName

        local object = StaticObject.getByName(unitName)

        if object then
            object:destroy()
        end
    end

    ---@class DrawColor
    ---@field r number
    ---@field g number
    ---@field b number
    ---@field a number

    local drawID = 400
    ---@param zone SpearheadTriggerZone
    ---@param lineColor DrawColor
    ---@param fillColor DrawColor
    ---@param lineStyle LineType
    ---@return number drawID
    function DCS_UTIL.DrawZone(zone, lineColor, fillColor, lineStyle)
        if lineStyle == nil then lineStyle = 4 end
        drawID = drawID + 1
        if zone.zone_type == "Cilinder" then
            trigger.action.circleToAll(-1, drawID, { x = zone.location.x, y = 0, z = zone.location.y }, zone.radius,
                { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, lineStyle, true)
        else
            local functionString = "trigger.action.markupToAll(7, -1, " .. drawID .. ","
            for _, vecpoint in pairs(zone.verts) do
                functionString = functionString .. " { x=" .. vecpoint.x .. ", y=0,z=" .. vecpoint.y .. "},"
            end
            functionString = functionString .. "{0,1,0,1}, {0,1,0,1}, " .. lineStyle .. ")"

            env.info(functionString)
            ---@diagnostic disable-next-line: deprecated
            local f, err = loadstring(functionString)
            if f then
                f()
            else
                env.error("Something failed when drawing complex drawing" .. err)
            end
        end
        local fillColorMapped = {
            fillColor.r or 0,
            fillColor.g or 0,
            fillColor.b or 0,
            fillColor.a or 0.5
        }

        local lineColorMapped = {
            lineColor.r or 0,
            lineColor.g or 0,
            lineColor.b or 0,
            lineColor.a or 1
        }

        trigger.action.setMarkupColorFill(drawID, fillColorMapped)
        trigger.action.setMarkupColor(drawID, lineColorMapped)

        return drawID
    end

    ---comment
    ---@param drawID number
    ---@param lineColor DrawColor
    function DCS_UTIL.SetLineColor(drawID, lineColor)
        local lineColorMapped = {
            lineColor.r or 0,
            lineColor.g or 0,
            lineColor.b or 0,
            lineColor.a or 1
        }
        trigger.action.setMarkupColor(drawID, lineColorMapped)
    end

    ---comment
    ---@param drawID number
    ---@param fillColor DrawColor
    function DCS_UTIL.SetFillColor(drawID, fillColor)
        local lineColorMapped = {
            fillColor.r or 0,
            fillColor.g or 0,
            fillColor.b or 0,
            fillColor.a or 1
        }
        trigger.action.setMarkupColorFill(drawID, lineColorMapped)
    end

    function DCS_UTIL.RemoveZoneDraw(drawID)
        if drawID ~= nil then
            trigger.action.removeMark(drawID)
        end
    end

    --- spawns the units as specified in the mission file itself
    --- location and route can be nil and will then use default route
    ---@param groupName string
    ---@param location table? vector 3 data. { x , z, alt }
    ---@param route table? route of the group. If nil wil be the default route.
    ---@param uncontrolled boolean? Sets the group to be uncontrolled on spawn
    ---@return table? new_group the Group class that was spawned
    ---@return boolean? isStatic whether the group is a static or not
    function DCS_UTIL.SpawnGroupTemplate(groupName, location, route, uncontrolled)
        if groupName == nil then
            return nil, nil
        end

        local template = DCS_UTIL.GetMizGroupOrDefault(groupName, nil)
        if template == nil then
            return nil, nil
        end
        if template.category == DCS_UTIL.GroupCategory.STATIC then
            --TODO: Implement location and route stuff
            local spawn_template = template.group_template
            return coalition.addStaticObject(template.country_id, spawn_template), true
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
            return new_group, false
        end
    end

    function DCS_UTIL.IsBingoFuel(groupName, offset)
        if offset == nil then offset = 0 end
        local bingoSetting = 0.20
        bingoSetting = bingoSetting + offset

        local group = Group.getByName(groupName)
        if group then
            for _, unit in pairs(group:getUnits()) do
                if unit and unit:isExist() == true and unit:inAir() == true and unit:getFuel() < bingoSetting then
                    return true
                end
            end
        end

        return false
    end

    ---comment
    ---@param groupId number
    ---@return Group?
    function DCS_UTIL.GetPlayerGroupByGroupID(groupId)
        for i = 0, 2 do
            local players = coalition.getPlayers(i)
            for key, unit in pairs(players) do
                if unit and unit:isExist() == true then
                    local group = unit:getGroup()
                    if group and group:getID() == groupId then
                        return group
                    end
                end
            end
        end
    end

    DCS_UTIL.__INIT();
end
Spearhead.DcsUtil = DCS_UTIL

--- @class Logger
--- @field LoggerName string the name of the logger
--- @field LogLevel string the log level of the logger
local LOGGER = {}
do
    local PreFix = "Spearhead"

    ---comment
    ---@param logger_name any
    ---@param logLevel LogLevel
    ---@return Logger
    function LOGGER.new(logger_name, logLevel)
        LOGGER.__index = LOGGER
        local self = setmetatable({}, LOGGER)
        self.LoggerName = logger_name or "(loggername not set)"
        self.LogLevel = logLevel or "INFO"

        return self
    end

    ---@param message any the message
    function LOGGER:info(message)
        if message == nil then
            return
        end
        message = UTIL.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" then
            env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---comment
    ---@param message string
    function LOGGER:warn(message)
        if message == nil then
            return
        end
        message = UTIL.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" then
            env.warning("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---@param message any -- the message
    function LOGGER:error(message)
        if message == nil then
            return
        end

        message = UTIL.toString(message)

        if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" or self.LogLevel == "ERROR" then
            env.error("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
        end
    end

    ---@param message any the message
    function LOGGER:debug(message)
        if message == nil then
            return
        end

        message = UTIL.toString(message)
        if self.LogLevel == "DEBUG" then
            env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "][DEBUG] " .. message)
        end
    end
end
Spearhead.LoggerTemplate = LOGGER

Spearhead.MissionEditingWarnings = {}
function Spearhead.AddMissionEditorWarning(warningMessage)
    table.insert(Spearhead.MissionEditingWarnings, warningMessage or "skip")
end

local loadDone = false
Spearhead.LoadingDone = function()
    if loadDone == true then
        return
    end

    local warningLogger = Spearhead.LoggerTemplate.new("MISSIONPARSER", "INFO")
    if Spearhead.Util.tableLength(Spearhead.MissionEditingWarnings) > 0 then
        for key, message in pairs(Spearhead.MissionEditingWarnings) do
            warningLogger:warn(message)
        end
    else
        warningLogger:info("No issues detected")
    end

    loadDone = true
end
