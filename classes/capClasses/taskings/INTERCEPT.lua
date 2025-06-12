

---@class InterceptTasking
local INTERCEPT = {}


---@param groupName string
---@param interceptPoint Vec2
---@param airbase Airbase
---@param speed number?
---@param alt number?
---@param config CapConfig
function INTERCEPT.getMissionFromAirbase(groupName, interceptPoint, airbase, config, speed, alt)

    local airbaseVec3 = airbase:getPoint()
    local airbaseVec2 = { x = airbaseVec3.x, y = airbaseVec3.z }
    local heading = Spearhead.Util.vectorHeadingFromTo(airbaseVec2, interceptPoint)

    env.info("BLAAT: heading from runway to first point: " .. heading)

    local point = Spearhead.Util.vectorMove(airbaseVec2, heading, 3*1852)

    local pointA, pointB, pointC, pointD = INTERCEPT.getInterceptTaskPoint(groupName, point, interceptPoint, airbaseVec2, config, speed, alt)

    local points = {
        [1] = pointA,
        [2] = pointA,
        [3] = pointB,
        [4] = pointC,
        [5] = pointD,
        [6] = Spearhead.classes.capClasses.taskings.RTB.getApproachPoint(airbase, interceptPoint, config),
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

---comment
---@param groupName string
---@param currentPosition Vec2
---@param interceptPoint Vec2
---@param airbase Airbase
---@param speed number?
---@param alt number?
---@param config CapConfig
---@return table
function INTERCEPT.getMissionFromInAir(groupName, currentPosition, interceptPoint, airbase, config, speed, alt)

    local pointAirbasev3 = airbase:getPoint()
    local airbase2 = { x = pointAirbasev3.x, y = pointAirbasev3.z }

    local pointA, pointB, pointC, pointD = INTERCEPT.getInterceptTaskPoint(groupName, currentPosition, interceptPoint, airbase2, config, speed, alt)

    local points = {
        [1] = pointA,
        [2] = pointA,
        [3] = pointB,
        [4] = pointC,
        [5] = pointD,
        [6] = Spearhead.classes.capClasses.taskings.RTB.getApproachPoint(airbase, interceptPoint, config),
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

---comment
---@param groupName string
---@param currentPoint Vec2
---@param targetPosition Vec2
---@param targetUnit Unit
---@param airbase any
---@param config any
---@param speed number?
---@param alt number?
---@return table
function INTERCEPT.getUnitInterceptMissionFromAir(groupName, currentPoint, targetPosition, targetUnit, airbase, config, speed, alt)

    local pointAirbasev3 = airbase:getPoint()
    local airbase2 = { x = pointAirbasev3.x, y = pointAirbasev3.z }

    local pointA, pointB, pointC, pointD = INTERCEPT.getUnitInterceptTaskPoint(groupName, currentPoint, targetPosition, targetUnit, airbase2, config, speed, alt)

    local points = {
        [1] = pointA,
        [2] = pointA,
        [3] = pointB,
        [4] = pointC,
        [5] = pointD,
        [6] = Spearhead.classes.capClasses.taskings.RTB.getApproachPoint(airbase, currentPoint, config),
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
---@param currentPoint Vec2
---@param targetPoint Vec2
---@param airbasePoint Vec2
---@param config CapConfig
---@param speed number?
---@param alt number?
---@return table pointA @Starts the task right away
---@return table pointB @The actual target point to fly to and search, but searching started at pointA
---@return table pointC A fly over point halfway between the target and the airbase, if nothing it found then the unit will fly it's route till here
---@return table pointD THe point after Point C where the unit will execute the RTB command
function INTERCEPT.getInterceptTaskPoint(groupName, currentPoint, targetPoint, airbasePoint, config, speed, alt)

    local pointA = {
        alt = alt or config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed or config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = currentPoint.x,
        y = currentPoint.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    id = 'EngageTargetsInZone',
                    params = { 
                        point = targetPoint,
                        zoneRadius = 10 * 1852,  -- 10 NM, point will be updated, so target should be in this zone.
                        targetTypes = { 
                            [1] = "Planes",
                        },
                        priority = 0
                    }
                }
            }
        }
    }

    local pointB = {
        alt = alt or config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed or config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = targetPoint.x,
        y = targetPoint.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    id = 'EngageTargetsInZone',
                    params = { 
                        point = targetPoint,
                        zoneRadius = 10 * 1852,  -- 10 NM, point will be updated, so target should be in this zone.
                        targetTypes = { 
                            [1] = "Planes",
                        },
                        priority = 0
                    }
                }
            }
        }
    }

    local midPoint = {
        x = (targetPoint.x + airbasePoint.x) / 2,
        y = (targetPoint.y + airbasePoint.y) / 2
    }

    local pointC = {
        alt = config:getMinAlt(),
        action = "Fly Over Point",
        alt_type = "BARO",
        speed = config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = midPoint.x,
        y = midPoint.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {}
        }
    }

    local pointD = {
        alt = config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = midPoint.x,
        y = midPoint.y,
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
                                    command = "pcall(Spearhead.Events.PublishRTB, \"" .. groupName .. "\")"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return pointA, pointB, pointC, pointD
end


---@private
---@param groupName string
---@param currentPoint Vec2
---@param targetPosition Vec2
---@param targetUnit Unit
---@param airbasePoint Vec2
---@param config CapConfig
---@param speed number?
---@param alt number?
---@return table pointA @Starts the task right away
---@return table pointB @The actual target point to fly to and search, but searching started at pointA
---@return table pointC A fly over point halfway between the target and the airbase, if nothing it found then the unit will fly it's route till here
---@return table pointD THe point after Point C where the unit will execute the RTB command
function INTERCEPT.getUnitInterceptTaskPoint(groupName, currentPoint, targetPosition, targetUnit, airbasePoint, config, speed, alt)

    local pointA = {
        alt = alt or config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed or config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = currentPoint.x,
        y = currentPoint.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                   [1] = {
                        id = 'EngageUnit',
                        params = {
                            unitId = targetUnit:getID(),
                            groupAttack = true,
                            priority = 0
                        }
                    }
                }
            }
        }
    }

    local pointB = {
        alt = alt or config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = speed or config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = targetPosition.x,
        y = targetPosition.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {
                tasks = {
                    [1] = {
                        id = 'EngageUnit',
                        params = {
                            unitId = targetUnit:getID(),
                            groupAttack = true,
                            priority = 0
                        }
                    }
                }
            }
        }
    }


    local midPoint = {
        x = (targetPosition.x + airbasePoint.x) / 2,
        y = (targetPosition.y + airbasePoint.y) / 2
    }

    local pointC = {
        alt = config:getMinAlt(),
        action = "Fly Over Point",
        alt_type = "BARO",
        speed = config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = midPoint.x,
        y = midPoint.y,
        speed_locked = true,
        formation_template = "",
        task = {
            id = "ComboTask",
            params = {}
        }
    }

    local pointD = {
        alt = config:getMinAlt(),
        action = "Turning Point",
        alt_type = "BARO",
        speed = config:getMaxSpeed(),
        ETA = 0,
        ETA_locked = false,
        x = midPoint.x,
        y = midPoint.y,
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
                                    command = "pcall(Spearhead.Events.PublishRTB, \"" .. groupName .. "\")"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return pointA, pointB, pointC, pointD
end


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.taskings then Spearhead.classes.capClasses.taskings = {} end
Spearhead.classes.capClasses.taskings.INTERCEPT = INTERCEPT