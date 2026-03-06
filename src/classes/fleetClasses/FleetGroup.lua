local Util = require("classes.util.Util")
local DcsUtil = require("classes.util.DcsUtil")
local MissionEditorWarning = require("classes.util.MissionEditorWarnings")
local RouteUtil = require("classes.spearhead_routeutil")
local SpearheadEvents = require("classes.spearhead_events")

---@class FleetGroup
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

    local split_name = Util.split_string(fleetGroupName, "_")
    if Util.tableLength(split_name) < 2 then
        MissionEditorWarning.Add("CARRIERGROUP should have at least 2 parts. CARRIERGROUP_<fleetname>")
        return nil
    end
    o.fleetNameIdentifier = split_name[2]

    o.targetZonePerStage = {}
    o.currentTargetZone = nil
    o.pointsPerZone = {}

    do --INIT
        local carrierRouteZones = database:getCarrierRouteZones()
        for _, zoneName in pairs(carrierRouteZones) do
            if Util.strContains(string.lower(zoneName), "_".. string.lower(o.fleetNameIdentifier) .. "_" ) == true then
                local zone = DcsUtil.getZoneByName(zoneName)
                if zone and zone.zone_type == DcsUtil.ZoneType.Polygon then
                    local split_string = Util.split_string(zoneName, "_")
                    if Util.tableLength(split_string) < 3 then
                        MissionEditorWarning.Add(
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
                                    local dist = Util.VectorDistance2d(a, b)

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

                            if Util.startswith(namePart, "%[") == true then
                                namePart =  Util.split_string(namePart, "[")[1]
                            end

                            if Util.strContains(namePart, "%]") == true then
                                namePart = Util.split_string(namePart, "]")[1]
                            end

                            local split_numbers = Util.split_string(namePart, "-")
                            if Util.tableLength(split_numbers) < 2  then
                                MissionEditorWarning.Add("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                                return nil, nil
                            end

                            local first = tonumber(split_numbers[1])
                            local second = tonumber(split_numbers[2])

                            if first == nil or second == nil  then
                                MissionEditorWarning.Add("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
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
                            MissionEditorWarning.Add("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                        end
                    end
                else
                    MissionEditorWarning.Add("CARRIERROUTE cannot be a cilinder: " .. zoneName)
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
            logger:info("Sending " .. groupName .. " to " .. targetZone)
            group:getController():setTask(task)
        end
    end

    o.OnStageNumberChanged = function(self, number)
        local targetZone = self.targetZonePerStage[tostring(number)]
        if targetZone and targetZone ~= self.currentTargetZone then
            local points = self.pointsPerZone[targetZone]
            local task  = RouteUtil.CreateCarrierRacetrack(points.pointA, points.pointB)
            timer.scheduleFunction(SetTaskAsync, { task = task, targetZone = targetZone,  groupName = self.fleetGroupName, logger = self.logger }, timer.getTime() + 5)
        end
    end

    SpearheadEvents.AddStageNumberChangedListener(o)
    return o
end

return FleetGroup
