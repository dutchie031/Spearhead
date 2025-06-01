
---@class RTBTasking
local RTB = {}


---@param airbase Airbase
---@param missionPoint Vec2
---@param capConfig CapConfig
function RTB.getAsMission(airbase, missionPoint, capConfig)
    return {
        id = "Mission",
        params = {
            airborne = true,
            route = {
                points = {
                    [1] = RTB.getApproachPoint(airbase, missionPoint, capConfig),
                    [2] = RTB.getInitialPoint(airbase),
                    [3] = RTB.getLandingPoint(airbase)
                }
            }
        }
    }

end

---@param airbase Airbase
---@return number
local getRunwayIntoWindCourseRad = function(airbase)

    local activeCourse = nil
    local minAlignment = nil

    local runways = airbase:getRunways()

    local windVec = atmosphere.getWind(airbase:getPoint())
    local mPerS = Spearhead.Util.vectorMagnitude(windVec)

    if mPerS > 0 then
        for i = 1, #runways do
            local runway = runways[i]

            do --normal
                local rad = runway.course
                if rad < 0 then
                    rad = math.abs(rad)
                else
                    rad = 0 - rad
                end
            
                local runwayVec = {x = math.cos(rad), z = math.sin(rad), y = 0}
                local alignment = Spearhead.Util.vectorAlignment(windVec, runwayVec)

                if minAlignment == nil or alignment < minAlignment then
                    activeCourse = i
                    minAlignment = alignment
                end
            end

            do --inverse 
                local degree = math.deg(runway.course)
                degree = (degree + 180) % 360
            
                local rad = math.rad(degree)
                if rad < 0 then
                    rad = math.abs(rad)
                else
                    rad = 0 - rad
                end
            
                local runwayVec = {x = math.cos(rad), z = math.sin(rad), y = 0}
                local alignment = Spearhead.Util.vectorAlignment(windVec, runwayVec)

                if minAlignment == nil or alignment < minAlignment then
                    activeCourse = i
                    minAlignment = alignment
                end
            end
        end
    end

    local rad = runways[1].course

    if activeCourse ~= nil then
        rad = runways[activeCourse].course
    end

    if rad < 0 then
        return math.abs(rad)
    else
        return 0 - rad
    end

end

---comment
---@param airbase Airbase
---@return Vec2
---@return number headingFromRunwayDegrees
local function calcInitialPoint(airbase)
    local runwayCourseRad = getRunwayIntoWindCourseRad(airbase)
    local heading = math.deg(runwayCourseRad)
    local flipped = heading + 180 % 360
    local basePoint = airbase:getPoint()
    local basePointVec2 = {x = basePoint.x, y = basePoint.z}
    local point = Spearhead.Util.vectorMove(basePointVec2, flipped, 22000)

    return point, flipped

end


---comment
---@param airbase Airbase
---@param missionPoint Vec2
---@param capConfig CapConfig
function RTB.getApproachPoint(airbase, missionPoint, capConfig)

    local initialPoint, headingFromRunway = calcInitialPoint(airbase)
    local pointA = Spearhead.Util.vectorMove(initialPoint, headingFromRunway - 45, 9000)
    local pointB = Spearhead.Util.vectorMove(initialPoint, headingFromRunway + 45, 9000)

    if Spearhead.Util.VectorDistance2d(missionPoint, pointA) > Spearhead.Util.VectorDistance2d(missionPoint, pointB) then
        pointA = pointB
    end

    return {
        alt = 3000,
        action = "Turning Point",
        alt_type = "BARO",
        speed = capConfig:getMinSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = pointA.x,
        y = pointA.y,
        speed_locked = true,
        formation_template = "",
        type = "Turning Point",
        task = {
            id = "ComboTask",
            params = {
                tasks = {}
            }
        }
    }

end

---@param airbase Airbase
function RTB.getInitialPoint(airbase)
    local point = calcInitialPoint(airbase)
    return {
        alt = 600,
        action = "Turning Point",
        alt_type = "BARO",
        speed = 180,
        ETA = 0,
        ETA_locked = false,
        x = point.x,
        y = point.y,
        speed_locked = true,
        formation_template = "",
        type = "Turning Point",
        task = {
            id = "ComboTask",
            params = {
                tasks = {}
            }
        }
    }
end

function RTB.getLandingPoint(airbase)
    local basePoint = airbase:getPoint()
    return {
        alt = basePoint.y,
        action = "Landing",
        alt_type = "BARO",
        speed = 70,
        ETA = 0,
        ETA_locked = false,
        x = basePoint.x,
        y = basePoint.z,
        speed_locked = true,
        formation_template = "",
        airdromeId = airbase:getID(),
        type = "Land",
        task = {
            id = "ComboTask",
            params = {
                tasks = {}
            }
        }
    }
end


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.taskings then Spearhead.classes.capClasses.taskings = {} end
Spearhead.classes.capClasses.taskings.RTB = RTB