
---@class RTBTasking
local RTB = {}


---@param airbase Airbase
function RTB.getAsMission(airbase, capConfig)
    return {
        id = "Mission",
        params = {
            airborne = true,
            route = {
                points = {
                    [1] = RTB.getApproachPoint(airbase, capConfig),
                    [2] = RTB.getInitialPoint(airbase),
                    [3] = RTB.getLandingPoint(airbase)
                }
            }
        }
    }

end

---@param airbase Airbase
---@return number
local getRunwayIntoWindCourse = function(airbase)

    local activeCourse = nil
    local minAlignment = nil

    local runways = airbase:getRunways()

    local windVec = atmosphere.getWind(airbase:getPoint())
    local mPerS = Spearhead.Util.vectorMagnitude(windVec)

    if mPerS > 0 then
        for i = 1, #runways do
            local runway = runways[i]

            do --normal
                local rad = math.rad(runway.course)
                local runwayVec = {x = math.cos(rad), z = math.sin(rad), y = 0}
                local alignment = Spearhead.Util.vectorAlignment(windVec, runwayVec)

                if minAlignment == nil or alignment < minAlignment then
                    activeCourse = i
                    minAlignment = alignment
                end
            end

            do --inverse 
                local inverseCourse = (runway.course + 180) % 360
                local rad = math.rad(inverseCourse)
                local runwayVec = {x = math.cos(rad), z = math.sin(rad), y = 0}
                local alignment = Spearhead.Util.vectorAlignment(windVec, runwayVec)

                if minAlignment == nil or alignment < minAlignment then
                    activeCourse = i
                    minAlignment = alignment
                end
            end
        end
    end

    if activeCourse == nil then
        return runways[1].course
    end
    return activeCourse
end

---comment
---@param airbase Airbase
---@param capConfig CapConfig
function RTB.getApproachPoint(airbase, capConfig)

    local speed = capConfig:getMinSpeed()
    local runwayCourse = getRunwayIntoWindCourse(airbase)
    local flipped = runwayCourse + 180 % 360
    local basePoint = airbase:getPoint()
    local basePointVec2 = {x = basePoint.x, y = basePoint.z}

    local point = Spearhead.Util.vectorMove(basePointVec2, flipped, 27000)
    return {
        alt = 600,
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed,
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

---@param airbase Airbase
function RTB.getInitialPoint(airbase)
    
    local runwayCourse = getRunwayIntoWindCourse(airbase)
    local flipped = runwayCourse + 180 % 360
    local basePoint = airbase:getPoint()
    local basePointVec2 = {x = basePoint.x, y = basePoint.z}

    local point = Spearhead.Util.vectorMove(basePointVec2, flipped, 22000)

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