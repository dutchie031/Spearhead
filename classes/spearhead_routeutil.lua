local ROUTE_UTIL = {}
ROUTE_UTIL.Tasks = {}


do --setup route util
    ---comment
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

    local function GetCasNoTargetTypes()
        return
        {
            [1] = "Fighters",
            [2] = "Multirole fighters",
            [3] = "Bombers",
            [4] = "Helicopters",
            [5] = "UAVs",
            [6] = "Fortifications",
            [7] = "SA Missiles",
            [8] = "MR SAM",
            [9] = "LR SAM",
            [10] = "Aircraft Carriers",
            [11] = "Cruisers",
            [12] = "Destroyers",
            [13] = "Frigates",
            [14] = "Corvettes",
            [15] = "Light armed ships",
            [16] = "Unarmed ships",
            [17] = "Submarines",
            [18] = "Cruise missiles",
            [19] = "Antiship Missiles",
            [20] = "AA Missiles",
            [21] = "AG Missiles",
        }
    end

    ---comment
    ---@param airdromeId number
    ---@param basePoint table { x, z, y } (y == alt)
    ---@param speed number the speed
    ---@return table task
    ROUTE_UTIL.Tasks.RtbTask = function(airdromeId, basePoint, speed)
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
    ROUTE_UTIL.Tasks.CapTask = function(groupName, position, altitude, speed, duration, engageHelos, deviationdistance, pattern)
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
                                    condition = "return Spearhead.internal.Air.IsBingo('" .. groupName .. "', 'CAP', 0.10)",
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
                                        command = "pcall(Spearhead.Events.PublishRTBInTen, '" .. groupName .. "')"
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
                                    condition = "return Spearhead.internal.Air.IsBingo('" .. groupName .. "','CAP')",
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
                                        command = "pcall(Spearhead.Events.PublishRTB, '" .. groupName .. "')"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    end
    


    ROUTE_UTIL.Tasks.CasInZonePoints = function(groupName, attackPosition, attackZoneRadius , altitude, speed, duration, orbitPointA, pattern)
        return {
            [1] = {
                alt = altitude,
                action = "Turning Point",
                type = "Turning Point",
                alt_type = "BARO",
                speed = speed,
                ETA = 0,
                ETA_locked = false,
                x = orbitPointA.x,
                y = orbitPointA.z,
                speed_locked = true,
                formation_template = "",
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                        }
                    }
                }
            },
            [2] = {
                alt = altitude,
                action = "Fly Over Point",
                type = "Turning Point",
                alt_type = "BARO",
                speed = speed,
                ETA = 0,
                ETA_locked = false,
                x = orbitPointA.x,
                y = orbitPointA.z,
                speed_locked = true,
                formation_template = "",
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                            [1] = {
                                id = 'EngageTargetsInZone',
                                number = 1,
                                enabled = true,
                                auto = false,
                                params = {
                                    x = attackPosition.x,
                                    y = attackPosition.z,
                                    zoneRadius = attackZoneRadius,
                                    value = "Ground Units;",
                                    targetTypes = {
                                        [1] = "Ground Units"
                                    },
                                    noTargetTypes = {
                                        [1] = "Helicopters",
                                        [2] = "Light armed ships",
                                    },
                                    priority = 0
                                }
                            }
                        }
                    }
                }
            },
            [3] = {
                alt = altitude,
                action = "Turning Point",
                type = "Turning Point",
                alt_type = "BARO",
                speed = speed,
                ETA = 0,
                ETA_locked = false,
                x = orbitPointA.x,
                y = orbitPointA.z,
                speed_locked = true,
                formation_template = "",
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                            [1] = {
                                number = 1,
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
                                        duration = duration,
                                        condition = "return Spearhead.internal.Air.IsBingo('" .. groupName .. "', 'CAP', 0.10)",
                                    }
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
                                            command = "pcall(Spearhead.Events.PublishRTB, '" .. groupName .. "')"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    end


    ROUTE_UTIL.Tasks.EscortTask = function(groupName, waitingPos, targetGroupName, engagementDistance, tillWaypoint)

        local group = Group.getByName(targetGroupName)
        if group then
            local groupId = group:getID()

            return {
                alt = 1500,
                action = "Turning Point",
                alt_type = "BARO",
                speed = 138,
                ETA = 0,
                ETA_locked = false,
                x = waitingPos.x,
                y = waitingPos.z,
                speed_locked = true,
                formation_template = "",
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                            [1] = {
                                enabled = true,
                                auto = false,
                                id = "Escort",
                                number = 1,
                                params = {
                                    groupId = groupId,
                                    engagementDistMax = engagementDistance,
                                    lastWptIndexFlagChangedManually = true,
                                    lastWptIndex = tillWaypoint,
                                    targetTypes = {
                                        [1] = "Fighters",
                                        [2] = "Multirole fighters",
                                        [3] = "Interceptors",
                                    },
                                    value = "Fighters;Multirole fighters;Interceptors;",
                                    lastWptIndexFlag = true,
                                    noTargetTypes = {
                                        [1] = "Bombers",
                                        [2] = "Helicopters",
                                        [3] = "UAVs",
                                    },
                                    pos = {
                                        x = -500,
                                        y = 0,
                                        z = 200
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
        end

        
    end

    ---comment
    ---@param groupName string
    ---@param point any
    ---@param speed any
    ---@param alt any
    ---@return table
    ROUTE_UTIL.Tasks.OrbitAtPointTask = function(groupName, point, speed, alt)

        return {
            alt = alt,
            action = "Turning Point",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = point.x,
            y = point.z,
            speed_locked = true,
            formation_template = "",
            task = {
                id = "ComboTask",
                params = {
                    tasks = {
                        [1] = {
                            number = 1,
                            auto = false,
                            id = "ControlledTask",
                            enabled = true,
                            params = {
                                task = {
                                    id = "Orbit",
                                    params = {
                                        altitude = alt,
                                        pattern = "Circle",
                                        speed = speed,
                                    }
                                },
                                stopCondition = {
                                    condition = "return Spearhead.internal.Air.IsBingo('" .. groupName .. "', 'CAP', 0.10)",
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
    ---@param position table { x, z }
    ---@param altitude number
    ---@param speed number
    ---@param childTasks table
    ---@return table
    ROUTE_UTIL.Tasks.FlyOverPointTask = function(position, altitude, speed, childTasks)
        return {
            alt = altitude,
            action = "Fly Over Point",
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
                [2] = ROUTE_UTIL.Tasks.CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = ROUTE_UTIL.Tasks.RtbTask(airdromeId, basePoint, speed)
            }
        else
            points = {
                [1] = FlyToPointTask(capPoint, altitude, speed, additionalFlyOverTasks),
                [2] = ROUTE_UTIL.Tasks.CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = FlyToPointTask(racetrackSecondPoint, altitude, speed, {}),
                [4] = ROUTE_UTIL.Tasks.RtbTask(airdromeId, basePoint, speed)
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
                        [3] = ROUTE_UTIL.Tasks.RtbTask(airdromeId, base:getPoint(), speed)
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

if Spearhead == nil then Spearhead = {} end
Spearhead.RouteUtil = ROUTE_UTIL
