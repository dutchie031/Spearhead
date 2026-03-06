local Util = require("classes.util.Util")

---DCS UTIL Takes inspiration from MIST but only takes the things it needs, changes for DCS updates and different vision for advanced mission scripting stuff.
---It also adds functions that make the other TDCS scripts easier without taking too much "control" away like MOOSE can sometimes.
---@class DcsUtil
local DCS_UTIL = {}
do     -- INIT DCS_UTIL
    do -- local databases
        --[=[
            groupdata = {
                category,
                country_id,
                group_template
            }
        --]=]

        --[[
            zone = {
                name,

                zone_type,
                x,
                y,
                radius
                verts,

            }
        something ]]

        ---@alias SpearheadTriggerZoneType
        ---| "Cilinder"
        ---| "Polygon"

        ---@class SpearheadTriggerZone
        ---@field name string
        ---@field location Vec2
        ---@field radius number
        ---@field verts Array<Vec2>
        ---@field zone_type SpearheadTriggerZoneType
        ---@field properties Array<KeyValuePair>?

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

    ---@enum SpearheadGroupCategory
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

            do --init trigger zones
                for i, trigger_zone in pairs(env.mission.triggers.zones) do
                    -- reorder verts as they are not ordered correctly in the ME
                    local verts = {}
                    if Util.tableLength(trigger_zone.verticies) >= 4 then
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
                        verts = verts,
                        properties = {}
                    }

                    if trigger_zone.properties then
                        for _, kvPair in pairs(trigger_zone.properties) do
                            local key = kvPair["key"]
                            local value = kvPair["value"]
                            zone.properties[#zone.properties + 1] = { key = key, value = value }
                        end
                    end

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
                            ---@type Array<Vec2>
                            local relevantPoints = {}
                            for _, x in pairs(airbase:getRunways()) do
                                if x.position and x.position.x and x.position.z then
                                    table.insert(relevantPoints, { x = x.position.x, y = x.position.z })
                                end
                            end

                            for _, x in pairs(airbase:getParking()) do
                                if x.vTerminalPos and x.vTerminalPos.x and x.vTerminalPos.z then
                                    table.insert(relevantPoints, { x = x.vTerminalPos.x, y = x.vTerminalPos.z })
                                end
                            end

                            local points = Util.getConvexHull(relevantPoints)
                            local enlargedPoints = Util.enlargeConvexHull(points, 750)

                            local triggerZone = {
                                name = name,
                                location = { x = airbase:getPoint().x, y = airbase:getPoint().z },
                                zone_type = "Polygon",
                                radius = 0,
                                verts = enlargedPoints
                            }

                            if SpearheadConfig and SpearheadConfig.debugEnabled == true then
                                DCS_UTIL.DrawZone(triggerZone, { r = 0, g = 1, b = 0, a = 1 }, { a = 0, r = 0, g = 1, b = 0 }, 1)
                            end

                            DCS_UTIL.__airbaseZonesByName[name] = triggerZone
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


    ---destroy the given unit
    ---@param unitName string
    function DCS_UTIL.DestroyUnit(unitName)
        local unit = Unit.getByName(unitName)
        if unit and unit:isExist() then
            unit:destroy()
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
                    local isInZone = Util.is3dPointInZone(unit_pos, zone)
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
        if Util.tableLength(group_names) < 1 then return {} end

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
            local isInZone = Util.is3dPointInZone(pos, zone)
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
            if Util.is3dPointInZone({ x = x, z = z, y = 0 }, zone) == true then
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
        if Util.is3dPointInZone({ x = x, y = 0, z = z }, zone) then
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
        return Util.is3dPointInZone({ x = zoneA.location.x, y = 0, z = zoneA.location.y }, zoneB)
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
    ---@return SpearheadTriggerZone? zone 
    function DCS_UTIL.getAirbaseZoneByName(airbaseName)
        if airbaseName == nil then return nil end
        return DCS_UTIL.__airbaseZonesByName[airbaseName]
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

    ---@type table<string, CoordType>
    local config =
    {
        ["ah-64d_blk_ii"] = "MGRS",
        ["fa-18c_hornet"] = "DMS",
        ["av8bna"] = "DMS",
        ["f-14b"] = "DMS",
        ["f-14a-135-gr"] = "DMS"
    }


    ---@param location Vec2
    ---@param unitType string
    function DCS_UTIL.convertVec2ToUnitUsableType(location, unitType)

        local height = land.getHeight(location)
        local vec3 = { x = location.x, y = height, z = location.y }

        local unitType = string.lower(unitType or "")
        local conversionType = config[unitType]

        if not conversionType then conversionType = "DDM" end
        return DCS_UTIL.convertToDisplayCoord(vec3, conversionType)
    end

    ---@alias CoordType
    ---| "MGRS" MGRS
    ---| "DMS" DECIMAL SECONDS
    ---| "DDM" DECIMAL MINUTES

    ---@private
    ---@param location Vec3
    ---@param coordType CoordType
    function DCS_UTIL.convertToDisplayCoord(location, coordType)
        local lattitude, longitude, altitude = coord.LOtoLL(location)

        if coordType == "MGRS" then
            local mgrs = coord.LLtoMGRS(lattitude, longitude)
            return string.format("%s %s %s %s", mgrs.UTMZone, mgrs.MGRSDigraph, mgrs.Easting, mgrs.Northing)
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

        if coordType == "DDM" then
            return string.format("%s%02d°%06.3f' %s%03d°%06.3f' %dft",
                lat_hemisphere, math.abs(lat_deg), lat_min,
                lon_hemisphere, math.abs(lon_deg), lon_min,
                altitude * 3,28084)
        end

        if coordType == "DMS" then

            local lat_min_display = math.floor(lat_min)
            local lon_min_display = math.floor(lon_min)

            local lat_sec_display = math.floor((lat_min - lat_min_display) * 60)
            local lon_sec_display = math.floor((lon_min - lon_min_display) * 60)

            return string.format("%s%02d°%02d'%02d %s%03d°%02d'%02d %dft",
                lat_hemisphere, math.abs(lat_deg), lat_min_display, lat_sec_display,
                lon_hemisphere, math.abs(lon_deg), lon_min_display, lon_sec_display,
                altitude * 3,28084)
        end
        
    end

    ---@param zone SpearheadTriggerZone
    ---@return Array<SpearheadSceneryObject> sceneryObjects
    function DCS_UTIL.getSceneryObjectsInZone(zone)
        ---@type Volume
        local volume

        if(zone.zone_type == "Cilinder") then
            local y = land.getHeight({ x = zone.location.x, y = zone.location.y })
            ---@type Sphere
            local sphere = {
                id = world.VolumeType.SPHERE,
                params = {
                    point = { x = zone.location.x, y = y, z = zone.location.y },
                    radius = zone.radius
                }
            }
            volume = sphere
        else
            local minX = nil
            local maxX = nil
            local minZ = nil
            local maxZ = nil

            for _, point in pairs(zone.verts) do
                if minX == nil or point.x < minX then
                    minX = point.x
                end
                if maxX == nil or point.x > maxX then
                    maxX = point.x
                end
                if minZ == nil or point.y < minZ then
                    minZ = point.y
                end
                if maxZ == nil or point.y > maxZ then
                    maxZ = point.y
                end
            end

            if(minX == nil or maxX == nil or minZ == nil or maxZ == nil) then
                return {}
            end

            ---@type Vec3
            local min = {
                x = minX,
                y = land.getHeight({ x = minX, y = minZ }) - 100,
                z = minZ
             }

            ---@type Vec3
            local max = {
                x = maxX,
                y = land.getHeight({ x = maxX, y = maxZ }) + 500,
                z = maxZ
             }

            ---@type Box
            local box = {
                id = world.VolumeType.BOX,
                params = {
                    min = min,
                    max = max
                }
            }
            volume = box
        end

        ---@type Array<SpearheadSceneryObject>
        local sceneryObjects = {}

        ---@param object SceneryObject
        local onFound = function(object)
            if object and object:isExist() and
                object:hasAttribute("Buildings")
            then
                local obj = Spearhead.classes.stageClasses.Groups.SpearheadSceneryObject.New(object["id_"])
                table.insert(sceneryObjects, obj)
            end
        end

        world.searchObjects(Object.Category.SCENERY, volume, onFound)
        return sceneryObjects
    end

    ---@param group Group
    function DCS_UTIL.getUnitTypeFromGroup(group)
        for _, unit in pairs(group:getUnits()) do
            if unit and unit:isExist() then
                return unit:getTypeName()
            end
        end
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

    ---@param start Vec3
    ---@param finish Vec3
    ---@param lineColor DrawColor
    ---@param lineStyle LineType
    function DCS_UTIL.DrawLine(start, finish, lineColor, lineStyle)
        if lineStyle == nil then lineStyle = 4 end
        drawID = drawID + 1

        local lineColorMapped = {
            lineColor.r or 0,
            lineColor.g or 0,
            lineColor.b or 0,
            lineColor.a or 1
        }

        trigger.action.lineToAll(-1, drawID, start, finish, lineColorMapped, lineStyle)
        return drawID
    end

    ---@param groupID number
    ---@param text string
    ---@param location Vec3
    ---@return number markID
    function DCS_UTIL.AddMarkToGroup(groupID, text, location)
        drawID = drawID + 1
        trigger.action.markToGroup(drawID, text, location, groupID, true, nil)
        return drawID
    end

    ---comment
    ---@param text any
    ---@param location Vec3
    ---@return integer
    function DCS_UTIL.AddMarkToAll(text, location)
        drawID = drawID + 1
        trigger.action.markToAll(drawID, text, location, true, nil)
        return drawID
    end

    ---@param markId number
    function DCS_UTIL.RemoveMark(markId)
        if markId ~= nil then
            trigger.action.removeMark(markId)
        end
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


    ---@return number? id
    function DCS_UTIL.GetNeutralCountry()
        for name, id in pairs(country.id) do
            if coalition.getCountryCoalition(id) == DCS_UTIL.Coalition.NEUTRAL then
                return id
            end
        end
    end


    function DCS_UTIL.NeedsRTBInTen(groupName, fuelOffset)

        local isBingo = DCS_UTIL.IsBingoFuel(groupName, fuelOffset)
        if isBingo then return true end

        local aliveUnits = 0
        local group = Group.getByName(groupName)
        if group then
            for _ , unit in pairs(group:getUnits()) do
                if unit and unit:isExist() == true and unit:inAir() == true then
                    aliveUnits = aliveUnits + 1
                end
            end

            if aliveUnits / group:getInitialSize() <= 0.5 then
                return true
            end
        end

        return false
    end

    ---@return boolean
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

    ---@param unitID number
    ---@return Unit?
    function DCS_UTIL.GetPlayerUnitByID(unitID)
        for i = 0, 2 do
            local players = coalition.getPlayers(i)
            for key, unit in pairs(players) do
                if unit and unit:getID() == unitID then
                    return unit
                end
            end
        end
    end

    DCS_UTIL.__INIT();
end
return DCS_UTIL
