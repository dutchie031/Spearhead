---@class Util
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

    ---@param orig table
    ---@return table copy
    function UTIL.deepCopyTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[UTIL.deepCopyTable(orig_key)] = UTIL.deepCopyTable(orig_value)
            end
            setmetatable(copy, UTIL.deepCopyTable(getmetatable(orig)))
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
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

    ---@param list Array 
    ---@param start number start
    ---@param n number length
    ---@return Array
    function UTIL.sublist(list, start, n)
        local result = {}
        for i = start, n do
            result[#result + 1] = list[i]
        end
        return result
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
                    table.insert(sb, "[\"" ..key .. "\"]" .. " = {\n");
                    table.insert(sb, table_print(value, indent + 2, done))
                    table.insert(sb, string.rep(" ", indent)) -- indent it
                    table.insert(sb, "},\n");
                elseif "number" == type(key) then
                    table.insert(sb, string.format("\"%s\",\n", tostring(value)))
                else
                    table.insert(sb, string.format(
                        "[\"%s\"] = \"%s\",\n", tostring(key), tostring(value)))
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

    ---@param vec Vec3
    ---@return Vec3
    function UTIL.vectorNormalize(vec)
        local magnitude = UTIL.vectorMagnitude(vec)
        if magnitude == 0 then
            return { x = 0, y = 0, z = 0 }
        end
        return { x = vec.x / magnitude, y = vec.y / magnitude, z = vec.z / magnitude }
    end

    ---@param vec Vec2
    ---@param direction number @in degrees
    ---@param distance number
    ---@return Vec2
    function UTIL.vectorMove(vec, direction, distance)
        local rad = math.rad(direction)
        local x = vec.x + (math.cos(rad) * distance)
        local y = vec.y + (math.sin(rad) * distance)

        return { x = x, y = y}
    end

    ---comment
    ---@param vec1 Vec2
    ---@param vec2 Vec2
    ---@return number in degrees
    function UTIL.vectorHeadingFromTo(vec1, vec2)
        local dx = vec2.x - vec1.x
        local dy = vec2.y - vec1.y
        local heading = math.deg(math.atan2(dy, dx))
        if heading < 0 then
            heading = heading + 360
        end
        return heading
    end



    ---@param vec1 Vec3
    ---@param vec2 Vec3
    ---@return number alignment a number in range [-1,1]. > 0 same direction. < 0 opposite direction
    function UTIL.vectorAlignment(vec1, vec2)
        local vec1Norm = UTIL.vectorNormalize(vec1)
        local vec2Norm = UTIL.vectorNormalize(vec2)

        return ((vec1Norm.x * vec2Norm.x) + (vec1Norm.y * vec2Norm.y) + (vec1Norm.z * vec2Norm.z))
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

    ---@param point Vec2
    ---@param zone SpearheadTriggerZone
    function UTIL.is2dPointInZone(point, zone)
        if zone.zone_type == "Polygon" and zone.verts then
            if UTIL.IsPointInPolygon(zone.verts, point.x, point.y) == true then
                return true
            end
        else
            if (((point.x - zone.location.x) ^ 2 + (point.y - zone.location.y) ^ 2) ^ 0.5 <= zone.radius) then
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

    ---Splits points into clusters with at least minSeparation between clusters, returns convex hull for each cluster
    ---@param points Array<Vec2>
    ---@param minSeparation number
    ---@return Array<Array<Vec2>> hulls
    function UTIL.getSeparatedConvexHulls(points, minSeparation)
        if #points == 0 then return {} end

        -- Simple clustering: group points that are within minSeparation of each other
        local clusters = {}
        local assigned = {}

        for i, p in ipairs(points) do
            if not assigned[i] then
                local cluster = { p }
                assigned[i] = true
                -- Find all points close to p (BFS)
                local queue = { i }
                while #queue > 0 do
                    local idx = table.remove(queue)
                    local base = points[idx]
                    for j, q in ipairs(points) do
                        if not assigned[j] then
                            local dx = base.x - q.x
                            local dy = base.y - q.y
                            if (dx * dx + dy * dy) <= (minSeparation * minSeparation) then
                                table.insert(cluster, q)
                                assigned[j] = true
                                table.insert(queue, j)
                            end
                        end
                    end
                end
                table.insert(clusters, cluster)
            end
        end

        -- Compute convex hull for each cluster
        local hulls = {}
        for _, cluster in ipairs(clusters) do
            local hull = UTIL.getConvexHull(cluster)
            if #hull > 0 then
                table.insert(hulls, hull)
            end
        end

        return hulls
    end

    ---@param points Array<Vec2>
    function UTIL.enlargeConvexHull(points, meters)
        if points == nil or #points == 0 then
            return {}
        end

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

    ---Returns hull points visible from origin (not blocked by hull edges)
---@param hull Array<Vec2>
---@param origin Vec2
---@return Array<Vec2>
function UTIL.GetVisibleHullPointsFromOrigin(hull, origin)
    local function segmentsIntersect(a, b, c, d)
        -- Helper: returns true if segment ab intersects cd (excluding endpoints)
        local function ccw(p1, p2, p3)
            return (p3.y - p1.y) * (p2.x - p1.x) > (p2.y - p1.y) * (p3.x - p1.x)
        end
        return (ccw(a, c, d) ~= ccw(b, c, d)) and (ccw(a, b, c) ~= ccw(a, b, d))
    end

    local n = #hull
    local visible = {}

    for i = 1, n do
        local p = hull[i]
        local isVisible = true

        -- Check against all hull edges except those incident to p
        for j = 1, n do
            local a = hull[j]
            local b = hull[(j % n) + 1]
            -- skip edges incident to p
            if (a ~= p and b ~= p) then
                if segmentsIntersect(origin, p, a, b) then
                    isVisible = false
                    break
                end
            end
        end

        if isVisible then
            table.insert(visible, p)
        end
    end

    return visible
end

---Returns the two tangent points ("scratch points") from origin to the convex hull
---@param hull Array<Vec2>
---@param origin Vec2
---@return Array<Vec2>
function UTIL.GetTangentHullPointsFromOrigin(hull, origin)

    if hull == nil or #hull <= 0 then
        return {}
    end

    local function orientation(a, b, c)
        -- Returns >0 if c is to the left of ab, <0 if to the right, 0 if colinear
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    end

    local n = #hull
    if n == 0 then return {} end
    if n == 1 then return { hull[1] } end

    -- Find left tangent: the hull point where all other points are to the right of the line from origin to that point
    local function findTangent(isLeft)
        local best = 1
        for i = 2, n do
            local o = orientation(origin, hull[best], hull[i])
            if (isLeft and o < 0) or (not isLeft and o > 0) then
                best = i
            end
        end
        return hull[best]
    end

    local leftTangent = findTangent(true)
    local rightTangent = findTangent(false)

    -- If tangents are the same (can happen if origin is colinear), only return one
    if leftTangent.x == rightTangent.x and leftTangent.y == rightTangent.y then
        return { leftTangent }
    else
        return { leftTangent, rightTangent }
    end
end

end

return UTIL