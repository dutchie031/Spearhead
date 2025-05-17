
---@alias SpearheadTriggerZoneType
---| "Cilinder"
---| "Polygon"

---@class SpearheadTriggerZone
---@field private name string
---@field private location Vec2
---@field private radius number
---@field private verts Array<Vec2>
---@field private zone_type SpearheadTriggerZoneType
local SpearheadTriggerZone = {}

---@type table<string, SpearheadTriggerZone>
local triggerZones = {}

---@type table<string, SpearheadTriggerZone>
local airbaseZones = {}

---@param name string
---@return SpearheadTriggerZone?
function SpearheadTriggerZone.getByName(name)
    return triggerZones[name]
end

---@param name string
---@return SpearheadTriggerZone?
function SpearheadTriggerZone.getByAirbaseName(name)
    return airbaseZones[name]
end


---@param x number
---@param y number
---@param radius number
---@param name string? @Will save and overwrite the trigger zone with the same name if it exists. Nill for temp zones.
---@return SpearheadTriggerZone
function SpearheadTriggerZone.newCircle(x, y, radius, name)
    ---@type SpearheadTriggerZone
    local self = setmetatable({}, { __index = SpearheadTriggerZone })

    self.name = "Circle"
    self.location = { x = x, y = y }
    self.radius = radius
    self.zone_type = "Cilinder"

    if name then
        self.name = name
        triggerZones[name] = self
    end
    return self
end

---@param x number
---@param y number
---@param verts Array<Vec2>
---@param name string? @Will save and overwrite the trigger zone with the same name if it exists. Nill for temp zones.
---@return SpearheadTriggerZone
function SpearheadTriggerZone.newPolygon(x, y, verts, name)
    ---@type SpearheadTriggerZone
    local self = setmetatable({}, { __index = SpearheadTriggerZone })

    self.location = { x = x, y = y }

    self.verts = verts
    self.zone_type = "Polygon"

    if name then
        self.name = name
        triggerZones[name] = self
    end

    return self
end

---@param airbase Airbase
---@return SpearheadTriggerZone
function SpearheadTriggerZone.newAirbaseZone(airbase)
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

    local points = Spearhead.Util.getConvexHull(relevantPoints)
    local enlargedPoints = Spearhead.Util.enlargeConvexHull(points, 750)

    local self = setmetatable({}, { __index = SpearheadTriggerZone })

    local pos = airbase:getPoint()
    self.location = { x = pos.x, y = pos.z }

    self.verts = enlargedPoints
    self.zone_type = "Polygon"

    self.name = airbase:getName()
    triggerZones[airbase:getName()] = self

    return self
end

---@param point Vec2
function SpearheadTriggerZone:IsInZone2d(point)
    if self.zone_type == "Cilinder" then
        if (((point.x - self.location.x) ^ 2 + (point.y - self.location.y) ^ 2) ^ 0.5 <= self.radius) then
                return true
        end
    elseif self.zone_type == "Polygon" then
        return Spearhead.Util.IsPointInPolygon(self.verts, point.x, point.y)
    end

    return false
end

---@param point Vec3
function SpearheadTriggerZone:IsInZone3d(point)
   
    if self.zone_type == "Cilinder" then
        if (((point.x - self.location.x) ^ 2 + (point.z - self.location.y) ^ 2) ^ 0.5 <= self.radius) then
                return true
        end
    elseif self.zone_type == "Polygon" then
        return Spearhead.Util.IsPointInPolygon(self.verts, point.x, point.z)
    end

    return false
end

if not Spearhead then Spearhead = {} end
if not Spearhead.shared then Spearhead.shared = {} end
Spearhead.shared.SpearheadTriggerZone = SpearheadTriggerZone