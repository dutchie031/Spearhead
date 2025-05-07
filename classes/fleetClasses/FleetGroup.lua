local FleetGroup = {}

---comment
---@param fleetGroupName string
---@param database Database
---@param logger Logger
---@return nil
function FleetGroup:new(fleetGroupName, database, logger)
    local o = {}

    setmetatable(o, { __index = self })

    o.fleetGroupName = fleetGroupName
    o.logger = logger

    local split_name = Spearhead.Util.split_string(fleetGroupName, "_")
    if Spearhead.Util.tableLength(split_name) < 2 then
        Spearhead.AddMissionEditorWarning("CARRIERGROUP should have at least 2 parts. CARRIERGROUP_<fleetname>")
        return nil
    end
    o.fleetNameIdentifier = split_name[2]

    o.targetZonePerStage = {}
    o.currentTargetZone = nil
    o.pointsPerZone = {}

    do --INIT
        local carrierRouteZones = database:getCarrierRouteZones()
        for _, zoneName in pairs(carrierRouteZones) do
            if Spearhead.Util.strContains(string.lower(zoneName), "_".. string.lower(o.fleetNameIdentifier) .. "_" ) == true then
                local zone = Spearhead.DcsUtil.getZoneByName(zoneName)
                if zone and zone.zone_type == Spearhead.DcsUtil.ZoneType.Polygon then
                    local split_string = Spearhead.Util.split_string(zoneName, "_")
                    if Spearhead.Util.tableLength(split_string) < 3 then
                        Spearhead.AddMissionEditorWarning(
                            "CARRIERROUTE should at least have 3 parts. Check the documentation for: " .. zoneName)
                    else

                        ---@param zone SpearheadTriggerZone
                        ---@return Vec2, Vec2
                        local function GetTwoFurthestPoints(zone)

                            local biggest = nil
                            local biggestA = zone.verts[1]
                            local biggestB = zone.verts[2]

                            for i = 1, 3 do
                                for ii = i + 1, 4 do
                                    local a = zone.verts[i]
                                    local b = zone.verts[ii]
                                    local dist = Spearhead.Util.VectorDistance2d(a, b)

                                    if biggest == nil or dist > biggest then
                                        biggestA = a
                                        biggestB = b
                                        biggest = dist
                                    end
                                end
                            end
                            return { x = biggestA.x, y = biggestA.y }, { x = biggestB.x, y = biggestB.y }
                        end

                        local function getMinMaxStage(namePart)
                            if namePart == nil then
                                return nil, nil
                            end

                            if Spearhead.Util.startswith(namePart, "%[") == true then
                                namePart = Spearhead.Util.split_string(namePart, "[")[1]
                            end

                            if Spearhead.Util.strContains(namePart, "%]") == true then
                                namePart = Spearhead.Util.split_string(namePart, "]")[1]
                            end

                            local split_numbers = Spearhead.Util.split_string(namePart, "-")
                            if Spearhead.Util.tableLength(split_numbers) < 2  then
                                Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                                return nil, nil
                            end

                            local first = tonumber(split_numbers[1])
                            local second = tonumber(split_numbers[2])

                            if first == nil or second == nil  then
                                Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                                return nil, nil
                            end
                            return first, second
                        end

                        local pointA, pointB = GetTwoFurthestPoints(zone)
                        local first, second = getMinMaxStage(split_string[3])
                        if first ~= nil and second ~= nil then
                            for i = first, second do
                                o.targetZonePerStage[tostring(i)] = zoneName
                            end
                            o.pointsPerZone[zoneName] = { pointA = { x = pointA.x, z = pointA.y, y = 0 }, pointB = { x = pointB.x, z = pointB.y, y = 0} }
                        else
                            Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                        end
                    end
                else
                    Spearhead.AddMissionEditorWarning("CARRIERROUTE cannot be a cilinder: " .. zoneName)
                end
            end
        end
    end

    local SetTaskAsync = function(input, time)
        local targetZone = input.targetZone
        local task = input.task
        local groupName = input.groupName
        local logger = input.logger

        local group = Group.getByName(groupName)
        if group then
            logger:info("Sending " .. fleetGroupName .. " to " .. targetZone)
            group:getController():setTask(task)
        end
    end

    o.OnStageNumberChanged = function(self, number)
        local targetZone = self.targetZonePerStage[tostring(number)]
        if targetZone and targetZone ~= self.currentTargetZone then
            local points = self.pointsPerZone[targetZone]
            local task  = Spearhead.RouteUtil.CreateCarrierRacetrack(points.pointA, points.pointB)
            timer.scheduleFunction(SetTaskAsync, { task = task, targetZone = targetZone,  groupName = self.fleetGroupName, logger = self.logger }, timer.getTime() + 5)
        end
    end

    Spearhead.Events.AddStageNumberChangedListener(o)
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.FleetGroup = FleetGroup
