---@class SWEEPTasking
local SWEEP = {}

---@param attackHelos boolean
---@return table
local function GetCAPTargetTypes(attackHelos)
    local targetTypes = {
        [1] = "Planes",
    }

    if attackHelos then
        targetTypes[2] = "Helicopters"
    end

    return targetTypes
end

---@class SWEEPTaskingOptions
---@field furthest Vec2
---@field closest Vec2

---@param capZone SpearheadTriggerZone
---@param airBase Airbase
---@return SWEEPTaskingOptions
local function GetCAPPointFromTriggerZone(airBase, capZone)
    local furthestA = nil
    local furthestB = nil

    local furthestDistance = 0

    for indexA, pointA in ipairs(capZone.verts) do
        for indexB, pointB in ipairs(capZone.verts) do
            if pointA ~= pointB then
                local distance = Spearhead.Util.VectorDistance2d(pointA, pointB)
                if distance > furthestDistance then
                    furthestDistance = distance
                    furthestA = indexA
                    furthestB = indexB
                end
            end
        end
    end

    local baseVec3 = airBase:getPoint()

    ---@type Vec2
    local baseVec2 = { x = baseVec3.x, y = baseVec3.z }

    local pointA = capZone.verts[furthestA]
    local pointB = capZone.verts[furthestB]
    local furthest = pointA
    local closest = pointB

    local heading = Spearhead.Util.vectorHeadingFromTo(pointA, pointB)

    if Spearhead.Util.VectorDistance2d(baseVec2, pointB) > Spearhead.Util.VectorDistance2d(baseVec2, pointA) then
        furthest = pointB
        closest = pointA
        heading = Spearhead.Util.vectorHeadingFromTo(pointB, pointA)
    end

    local distance = furthestDistance
    if distance > 15000 then
        distance = distance - 10000
    end

    return {
        width = 10000,
        furthest = furthest,
        closest = closest,
        legLength = distance,
        hotLegDir = math.rad(heading),
        orbitOriginPoint = closest
    }
end

---@param airbase Airbase
---@param capZone SpearheadTriggerZone
---@param capConfig CapConfig
local GetOutboundTask = function(airbase, capZone, capConfig)
    local airbaseVec3 = airbase:getPoint()
    local airbaseVec2 = { x = airbaseVec3.x, y = airbaseVec3.z }
    local heading = Spearhead.Util.vectorHeadingFromTo(airbaseVec2, capZone.location)
    local point = Spearhead.Util.vectorMove(airbaseVec2, heading, 18520)

    return {
        alt = 2000,
        action = "Fly Over Point",
        type = "Turning Point",
        alt_type = "BARO",
        speed = capConfig:getMinSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = point.x,
        y = point.y,
        speed_locked = false,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    [1] = {
                        id = 'EngageTargets',
                        params = {
                            maxDist = capConfig:getMaxDeviationRange(),
                            maxDistEnabled = capConfig:getMaxDeviationRange() > 0,     -- required to check maxDist
                            targetTypes = GetCAPTargetTypes(false),
                            priority = 0
                        }
                    },
                }
            }
        }
    }
end

---@param groupName string
---@param airbase Airbase
---@param capZone SpearheadTriggerZone
---@param capConfig CapConfig
function SWEEP.getAsMissionFromAirbase(groupName, airbase, capZone, capConfig)

    local pointA, pointB, pointC = SWEEP.getAsTasking(groupName, airbase, capZone, capConfig)

    local points = {
        [1] = GetOutboundTask(airbase, capZone, capConfig),
        [2] = GetOutboundTask(airbase, capZone, capConfig),
        [3] = pointA,
        [4] = pointB,
        [5] = pointC,
        [6] = Spearhead.classes.capClasses.taskings.RTB.getApproachPoint(airbase, capZone.location, capConfig),
        [7] = Spearhead.classes.capClasses.taskings.RTB.getInitialPoint(airbase),
        [8] = Spearhead.classes.capClasses.taskings.RTB.getLandingPoint(airbase)
    }

    local mission = {
        id = 'Mission',
        params = {
            airborne = true,
            route = {
                points = points
            }
        }
    }

    return mission
end

---@private
---@param groupName string
---@param airbase Airbase
---@param capZone SpearheadTriggerZone
---@param capConfig CapConfig
---@return table TurningPointA
---@return table TurningPointB
---@return table TurningPointC
function SWEEP.getAsTasking(groupName, airbase, capZone, capConfig)

    local capTaskingOptions = GetCAPPointFromTriggerZone(airbase, capZone)


    local alt = math.random(capConfig:getMinAlt(), capConfig:getMaxAlt())
    local speed = capConfig:getMaxSpeed()

    local pointA =  {
        alt = alt,
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed,
        ETA = 0,
        ETA_locked = false,
        x = capTaskingOptions.closest.x,
        y = capTaskingOptions.closest.y,
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
                            maxDist = capConfig:getMaxDeviationRange(),
                            maxDistEnabled = capConfig:getMaxDeviationRange() >= 0, -- required to check maxDist
                            targetTypes = GetCAPTargetTypes(false),
                            priority = 0
                        }
                    }
                }
            }
        }
    }

    local pointB =  {
        alt = alt,
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed,
        ETA = 0,
        ETA_locked = false,
        x = capTaskingOptions.furthest.x,
        y = capTaskingOptions.furthest.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    [1] = {
                        id = 'EngageTargets',
                        params = {
                            maxDist = capConfig:getMaxDeviationRange(),
                            maxDistEnabled = capConfig:getMaxDeviationRange() >= 0, -- required to check maxDist
                            targetTypes = GetCAPTargetTypes(false),
                            priority = 0
                        }
                    }
                }
            }
        }
    }

    local pointC =  {
        alt = alt,
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed,
        ETA = 0,
        ETA_locked = false,
        x = capTaskingOptions.closest.x,
        y = capTaskingOptions.closest.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    [1] = {
                        id = 'EngageTargets',
                        params = {
                            maxDist = capConfig:getMaxDeviationRange(),
                            maxDistEnabled = capConfig:getMaxDeviationRange() >= 0, -- required to check maxDist
                            targetTypes = GetCAPTargetTypes(false),
                            priority = 0
                        }
                    },
                    [2] = {
                        number = 2,
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

    return pointA, pointB, pointC
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.taskings then Spearhead.classes.capClasses.taskings = {} end
Spearhead.classes.capClasses.taskings.SWEEP = SWEEP
