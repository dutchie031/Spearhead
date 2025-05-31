---@class CAPTasking : Tasking
local CAP = {}

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

function CAP.getAsMission()
    
end

function CAP.getAsTasking(groupName, position, altitude, speed, duration, engageHelos, deviationdistance, pattern)
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
                            maxDistEnabled = deviationdistance >= 0,     -- required to check maxDist
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


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.taskings then Spearhead.classes.capClasses.taskings = {} end
Spearhead.classes.capClasses.taskings.CAP = CAP