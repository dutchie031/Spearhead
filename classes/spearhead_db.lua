
---@class DatabaseTables
---@field AllZoneNames Array<string> All Zone Names
---@field StageZones Array<string> All Stage Zone Names
---@field MissionZones Array<string> All Mission Zone Names
---@field StageZonesByNumber table<integer, Array<string>> Stage zones grouped by index number
---@field StageNumberByZone table<string, string> : table<ZoneName, IndexAsString>
---@field RandomMissionZones Array<string> All Random mission names
---@field FarpZones Array<string> All farp zone names
---@field CapRoutes Array<string> All Cap route zone names
---@field CarrierRouteZones Array<string> All Carrier routes zones
---@field BlueSams Array<string> All blue sam zones
---@field DescriptionsByMission table<string,string> table<ZoneName, Description>


---@class Database
---@field private _tables DatabaseTables
---@field private _logger Logger 
local Database = {}

---comment
---@param Logger table
---@return Database
function Database.New(Logger, debug)
    
    ---@type DatabaseTables
    local tables = {
        AllZoneNames = {},
        BlueSams = {},
        CapRoutes = {},
        CarrierRouteZones = {},
        FarpZones = {},
        MissionZones = {},
        RandomMissionZones = {},
        StageZones = {},
        StageZonesByNumber = {},
        StageNumberByZone = {},
        DescriptionsByMission = {}
    }

    Database.__index = Database
    local self = setmetatable({}, Database)

    self._logger = Logger
    self._tables = tables

    Logger:debug("Initiating tables")

    do -- INIT ZONE TABLES
        for zone_ind, zone_data in pairs(Spearhead.DcsUtil.__trigger_zones) do
            local zone_name = zone_data.name
            local split_string = Spearhead.Util.split_string(zone_name, "_")
            table.insert(self._tables.AllZoneNames, zone_name)

            if string.lower(split_string[1]) == "missionstage" then
                table.insert(self._tables.StageZones, zone_name)
                if split_string[2] then
                    local stringified = tostring(split_string[2]) or "unknown"
                    if self._tables.StageZonesByNumber[stringified] == nil then
                        self._tables.StageZonesByNumber[stringified] = {}
                    end
                    table.insert(self._tables.StageZonesByNumber[stringified], zone_name)
                    self._tables.StageNumberByZone[zone_name] = stringified
                end
            end

            if string.lower(split_string[1]) == "waitingstage" then
                table.insert(self._tables.StageZones, zone_name)
            end

            if string.lower(split_string[1]) == "mission" then
                table.insert(self._tables.MissionZones, zone_name)
            end

            if string.lower(split_string[1]) == "randommission" then
                table.insert(self._tables.RandomMissionZones, zone_name)
            end

            if string.lower(split_string[1]) == "farp" then
                table.insert(self._tables.FarpZones, zone_name)
            end

            if string.lower(split_string[1]) == "caproute" then
                table.insert(self._tables.CapRoutes, zone_name)
            end

            if string.lower(split_string[1]) == "carrierroute" then
                table.insert(self._tables.CarrierRouteZones, zone_name)
            end

            if string.lower(split_string[1]) == "bluesam" then
                table.insert(self._tables.BlueSams, zone_name)
            end
        end
    end

    Logger:debug("initiated zone tables, continuing with descriptions")
    do --load markers
        if env.mission.drawings and env.mission.drawings.layers then
            for i, layer in pairs(env.mission.drawings.layers) do
                if string.lower(layer.name) == "author" then
                    for key, layer_object in pairs(layer.objects) do

                        if Spearhead.Util.startswith(layer_object.name,  "stagebriefing", true) then
                            
                        else
                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY,
                            o.tables.mission_zones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    self._tables.DescriptionsByMission[name] = layer_object.text
                                end
                            end

                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY,
                                o.tables.random_mission_zones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    o.tables.descriptions[name] = layer_object.text
                                end
                            end
                        end

                        
                    end
                end
            end
        end
    end

    o.tables.blueSamZonesPerStage = {}
    for _, stageZoneName in pairs(o.tables.stage_zones) do
    
        if o.tables.blueSamZonesPerStage[stageZoneName] == nil then
            o.tables.blueSamZonesPerStage[stageZoneName] = {}
        end
        
        for _, blueSamStageName in pairs(o.tables.blue_sams) do
            
            if Spearhead.DcsUtil.isZoneInZone(blueSamStageName, stageZoneName) == true then
                table.insert(o.tables.blueSamZonesPerStage[stageZoneName], blueSamStageName)
            end
        end
    end
    
    o.tables.missionZonesPerStage = {}
    for key, missionZone in pairs(o.tables.mission_zones) do
        local found = false
        local i = 1
        while found == false and i <= Spearhead.Util.tableLength(o.tables.stage_zones) do
            local stageZone = o.tables.stage_zones[i]
            if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZone) == true then
                if o.tables.missionZonesPerStage[stageZone] == nil then
                    o.tables.missionZonesPerStage[stageZone] = {}
                end
                table.insert(o.tables.missionZonesPerStage[stageZone], missionZone)
            end
            i = i + 1
        end
    end

    o.tables.randomMissionZonesPerStage = {}
    for key, missionZone in pairs(o.tables.random_mission_zones) do
        local found = false
        local i = 1
        while found == false and i <= Spearhead.Util.tableLength(o.tables.stage_zones) do
            local stageZone = o.tables.stage_zones[i]
            if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZone) == true then
                if o.tables.randomMissionZonesPerStage[stageZone] == nil then
                    o.tables.randomMissionZonesPerStage[stageZone] = {}
                end
                table.insert(o.tables.randomMissionZonesPerStage[stageZone], missionZone)
            end
            i = i + 1
        end
    end

    local isAirbaseInZone = {}
    o.tables.airbasesPerStage = {}
    o.tables.farpIdsInFarpZones = {}
    local airbases = world.getAirbases()
    for _, airbase in pairs(airbases) do
        local baseId = airbase:getID()
        local point = airbase:getPoint()
        local found = false
        for _, zoneName in pairs(o.tables.stage_zones) do
            if found == false then
                if Spearhead.DcsUtil.isPositionInZone(point.x, point.z, zoneName) == true then
                    found = true
                    local baseIdString = tostring(baseId) or "nil"
                    isAirbaseInZone[baseIdString] = true

                    if airbase:getDesc().category == 0 then
                        if o.tables.airbasesPerStage[zoneName] == nil then
                            o.tables.airbasesPerStage[zoneName] = {}
                        end

                        table.insert(o.tables.airbasesPerStage[zoneName], baseId)
                    else
                        -- farp
                        local i = 1
                        local farpFound = false
                        while farpFound == false and i <= Spearhead.Util.tableLength(o.tables.farp_zones) do
                            local farpZoneName = o.tables.farp_zones[i]
                            if Spearhead.DcsUtil.isPositionInZone(point.x, point.z, farpZoneName) == true then
                                farpFound = true

                                if o.tables.farpIdsInFarpZones[farpZoneName] == nil then
                                    o.tables.farpIdsInFarpZones[farpZoneName] = {}
                                end

                                table.insert(o.tables.farpIdsInFarpZones[farpZoneName], baseIdString)
                            end
                            i = i + 1
                        end
                    end
                end
            end
        end
    end



    o.tables.farpZonesPerStage = {}
    for _, farpZoneName in pairs(o.tables.farp_zones) do
        local findFirst = function(farpZoneName)
            for _, stage_zone in pairs(o.tables.stage_zones) do
                if Spearhead.DcsUtil.isZoneInZone(farpZoneName, stage_zone) then
                    return stage_zone
                end
            end
            return nil
        end

        local found = findFirst(farpZoneName)
        if found then
            if o.tables.farpZonesPerStage[found] == nil then
                o.tables.farpZonesPerStage[found] = {}
            end

            table.insert(o.tables.farpZonesPerStage[found], farpZoneName)
        end
    end


    local is_group_taken = {}
    do
        local all_groups = Spearhead.DcsUtil.getAllGroupNames()
        for _, value in pairs(all_groups) do
            is_group_taken[value] = false
        end
    end

    local getAvailableGroups = function()
        local result = {}
        for name, value in pairs(is_group_taken) do
            if value == false then
                table.insert(result, name)
            end
        end
        return result
    end

    local getAvailableCAPGroups = function()
        local result = {}
        for name, value in pairs(is_group_taken) do
            if value == false and Spearhead.Util.startswith(name, "CAP") then
                table.insert(result, name)
            end
        end
        return result
    end

    --- airbaseId <> groupname[]
    o.tables.capGroupsOnAirbase = {}
    local loadCapUnits = function()
        local all_groups = getAvailableCAPGroups()
        local airbases = world.getAirbases()
        for _, airbase in pairs(airbases) do
            local baseId = airbase:getID()
            local point = airbase:getPoint()
            local zone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or
            { x = point.x, z = point.z, radius = 4000 }
            o.tables.capGroupsOnAirbase[baseId] = {}
            local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, zone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(o.tables.capGroupsOnAirbase[baseId], groupName)
            end
        end
    end


    o.tables.samUnitsPerSamZone = {}
    local loadBlueSamUnits = function()
        local all_groups = Spearhead.DcsUtil.getAllGroupNames()
        for _, blueSamZone in pairs(o.tables.blue_sams) do
            o.tables.samUnitsPerSamZone[blueSamZone] = {}
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, blueSamZone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(o.tables.samUnitsPerSamZone[blueSamZone], groupName)
            end
        end
    end


    --- missionZoneName <> groupname[]
    o.tables.groupsInMissionZone = {}
    local loadMissionzoneUnits = function()
        local all_groups = getAvailableGroups()
        for _, missionZoneName in pairs(o.tables.mission_zones) do
            o.tables.groupsInMissionZone[missionZoneName] = {}
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(o.tables.groupsInMissionZone[missionZoneName], groupName)
            end
        end
    end

    --- missionZoneName <> groupname[]
    o.tables.groupsInRandomMissions = {}
    local loadRandomMissionzoneUnits = function()
        local all_groups = getAvailableGroups()
        for _, missionZoneName in pairs(o.tables.random_mission_zones) do
            o.tables.groupsInRandomMissions[missionZoneName] = {}
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(o.tables.groupsInRandomMissions[missionZoneName], groupName)
            end
        end
    end

    --- farpZoneName <> groupname[]
    o.tables.groupsInFarpZone = {}
    local loadFarpGroups = function()
        local all_groups = getAvailableGroups()
        for _, farpZone in pairs(o.tables.farp_zones) do
            o.tables.groupsInFarpZone[farpZone] = {}
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, farpZone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(o.tables.groupsInFarpZone[farpZone], groupName)
            end
        end
    end

    --- farpZoneName <> groupname[]
    o.tables.redAirbaseGroupsPerAirbase = {}
    o.tables.blueAirbaseGroupsPerAirbase = {}
    local loadAirbaseGroups = function()
        local all_groups = getAvailableGroups()
        local airbases = world.getAirbases()
        for _, airbase in pairs(airbases) do
            local baseId = tostring(airbase:getID())
            local point = airbase:getPoint()
            local airbaseZone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or
            { x = point.x, z = point.z, radius = 4000 }

            if isAirbaseInZone[tostring(baseId) or "something"] == true and airbaseZone and airbase:getDesc().category == Airbase.Category.AIRDROME then
                if debug then
                    if airbaseZone.zone_type == Spearhead.DcsUtil.ZoneType.Polygon then
                        local functionString = "trigger.action.markupToAll(7, -1, " .. baseId + 300 .. ","
                        for _, vecpoint in pairs(airbaseZone.verts) do
                            functionString = functionString .. " { x=" .. vecpoint.x .. ", y=0,z=" .. vecpoint.z ..
                            "},"
                        end
                        functionString = functionString .. "{0,1,0,1}, {0,0,0,0}, 1)"

                        env.info(functionString)
                        local f, err = loadstring(functionString)
                        if f then
                            f()
                        else
                            env.info(err)
                        end
                    else
                        trigger.action.circleToAll(-1, baseId, { x = point.x, y = 0, z = point.z }, 2048,
                            { 1, 0, 0, 1 }, { 0, 0, 0, 0 }, 1, true)
                    end
                end


                o.tables.redAirbaseGroupsPerAirbase[baseId] = {}
                o.tables.blueAirbaseGroupsPerAirbase[baseId] = {}
                local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, airbaseZone)
                for _, groupName in pairs(groups) do
                    if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                        local object = StaticObject.getByName(groupName)
                        if object then
                            if object:getCoalition() == coalition.side.RED then
                                table.insert(o.tables.redAirbaseGroupsPerAirbase[baseId], groupName)
                                is_group_taken[groupName] = true
                            elseif object:getCoalition() == coalition.side.BLUE then
                                table.insert(o.tables.blueAirbaseGroupsPerAirbase[baseId], groupName)
                                is_group_taken[groupName] = true
                            end
                        end
                    else
                        local group = Group.getByName(groupName)
                        if group then
                            if group:getCoalition() == coalition.side.RED then
                                table.insert(o.tables.redAirbaseGroupsPerAirbase[baseId], groupName)
                                is_group_taken[groupName] = true
                            elseif group:getCoalition() == coalition.side.BLUE then
                                table.insert(o.tables.blueAirbaseGroupsPerAirbase[baseId], groupName)
                                is_group_taken[groupName] = true
                            end
                        end
                    end
                end
            end
        end
    end

    o.tables.miscGroupsInStages = {}
    local loadMiscGroupsInStages = function()
        local all_groups = getAvailableGroups()
        for _, stage_zone in pairs(o.tables.stage_zones) do
            o.tables.miscGroupsInStages[stage_zone] = {}
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, stage_zone)
            for _, groupName in pairs(groups) do
                if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                    local object = StaticObject.getByName(groupName)
                    if object and object:getCoalition() ~= coalition.side.NEUTRAL then
                        is_group_taken[groupName] = true
                        table.insert(o.tables.miscGroupsInStages[stage_zone], groupName)
                    end
                else
                    local group = Group.getByName(groupName)
                    if group and group:getCoalition() ~= coalition.side.NEUTRAL then
                        is_group_taken[groupName] = true
                        table.insert(o.tables.miscGroupsInStages[stage_zone], groupName)
                    end
                end
            end
        end
    end

    loadCapUnits()
    loadBlueSamUnits()
    loadMissionzoneUnits()
    loadRandomMissionzoneUnits()
    loadFarpGroups()
    loadAirbaseGroups()
    loadMiscGroupsInStages()

    --- key: zoneName value: { current, routes = [ { point1, point2 } ] }
    o.tables.capRoutesPerStageNumber = {}
    for _, zoneName in pairs(o.tables.stage_zones) do
        local number = tostring(o.tables.stage_numberPerzone[zoneName] or "unknown")

        if o.tables.capRoutesPerStageNumber[number] == nil then
            o.tables.capRoutesPerStageNumber[number] = {
                current = 0,
                routes = {}
            }
        end

        for _, cap_route_zone in pairs(o.tables.cap_route_zones) do
            if Spearhead.DcsUtil.isZoneInZone(cap_route_zone, zoneName) == true then
                local zone = Spearhead.DcsUtil.getZoneByName(cap_route_zone)
                if zone then
                    if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                        table.insert(o.tables.capRoutesPerStageNumber[number].routes,
                            { point1 = { x = zone.x, z = zone.z }, point2 = nil })
                    else
                        local function getDist(a, b)
                            return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
                        end

                        local biggest = nil
                        local biggestA = nil
                        local biggestB = nil

                        for i = 1, 3 do
                            for ii = i + 1, 4 do
                                local a = zone.verts[i]
                                local b = zone.verts[ii]
                                local dist = getDist(a, b)

                                if biggest == nil or dist > biggest then
                                    biggestA = a
                                    biggestB = b
                                    biggest = dist
                                end
                            end
                        end

                        if biggestA and biggestB then
                            table.insert(o.tables.capRoutesPerStageNumber[number].routes,
                                {
                                    point1 = { x = biggestA.x, z = biggestA.z },
                                    point2 = { x = biggestB.x, z = biggestB.z }
                                })
                        end
                    end
                end
            end
        end
    end

    o.Logger:debug(o.tables.capRoutesPerStageNumber)

    o.tables.missionCodes = {}

end

        function o:GetDescriptionForMission(missionZoneName)
            return self.tables.descriptions[missionZoneName]
        end

        function o.getCapRouteInZone(stageNumber, baseId)
            local stageNumber = tostring(stageNumber) or "nothing"
            local routeData = self.tables.capRoutesPerStageNumber[stageNumber]
            if routeData then
                local count = Spearhead.Util.tableLength(routeData.routes)
                if count > 0 then
                    routeData.current = routeData.current + 1
                    if count < routeData.current then
                        routeData.current = 1
                    end
                    return routeData.routes[routeData.current]
                end
            end
            do
                local function GetClosestPointOnCircle(pC, radius, p)
                    local vX = p.x - pC.x;
                    local vY = p.z - pC.z;
                    local magV = math.sqrt(vX * vX + vY * vY);
                    local aX = pC.x + vX / magV * radius;
                    local aY = pC.z + vY / magV * radius;
                    return { x = aX, z = aY }
                end
                local stageZoneName = Spearhead.Util.randomFromList(self.tables.stage_zonesByNumer[stageNumber]) or
                "none"
                local stagezone = Spearhead.DcsUtil.getZoneByName(stageZoneName)
                if stagezone then
                    local base = Spearhead.DcsUtil.getAirbaseById(baseId)
                    if base then
                        local closest = nil
                        if stagezone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                            closest = GetClosestPointOnCircle({ x = stagezone.x, z = stagezone.z }, stagezone.radius,
                                base:getPoint())
                        else
                            local function getDist(a, b)
                                return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
                            end

                            local closestDistance = -1
                            for _, vert in pairs(stagezone.verts) do
                                local distance = getDist(vert, base:getPoint())
                                if closestDistance == -1 or distance < closestDistance then
                                    closestDistance = distance
                                    closest = vert
                                end
                            end
                        end

                        if math.random(1, 2) % 2 == 0 then
                            return { point1 = closest, point2 = { x = stagezone.x, z = stagezone.z } }
                        else
                            return { point1 = { x = stagezone.x, z = stagezone.z }, point2 = closest }
                        end
                    end
                end
            end
        end
        ---comment
        ---@param self table
        ---@return table result a  list of stage zone names
        o.getStagezoneNames = function(self)
            return self.tables.stage_zones
        end

        o.getCarrierRouteZones = function(self)
            return self.tables.carrier_route_zones
        end

        o.getMissionsForStage = function(self, stagename)
            return self.tables.missionZonesPerStage[stagename] or {}
        end

        o.getRandomMissionsForStage = function(self, stagename)
            return self.tables.randomMissionZonesPerStage[stagename] or {}
        end

        o.getGroupsForMissionZone = function(self, missionZoneName)
            if Spearhead.Util.startswith(missionZoneName, "RANDOMMISSION") == true then
                return self.tables.groupsInRandomMissions[missionZoneName] or {}
            end
            return self.tables.groupsInMissionZone[missionZoneName] or {}
        end

        o.getMissionBriefingForMissionZone = function(self, missionZoneName)
            return self.tables.descriptions[missionZoneName] or ""
        end

        ---@param self table
        ---@param stageName string
        ---@return table result airbase IDs. Use Spearhead.DcsUtil.getAirbaseById
        o.getAirbaseIdsInStage = function(self, stageName)
            return self.tables.airbasesPerStage[stageName] or {}
        end

        o.getFarpZonesInStage = function(self, stageName)
            return self.tables.farpZonesPerStage[stageName]
        end

        o.getFarpPadsInFarpZone = function(self, farpZoneName)
            return self.tables.farpIdsInFarpZones[farpZoneName]
        end

        o.getGroupsInFarpZone = function(self, farpZoneName)
            return self.tables.groupsInFarpZone[farpZoneName]
        end

        ---@param self table
        ---@param airbaseId number
        ---@return table
        o.getCapGroupsAtAirbase = function(self, airbaseId)
            return self.tables.capGroupsOnAirbase[airbaseId] or {}
        end

        ---@param stageName string
        ---@return table
        function o:getBlueSamsInStage(stageName)
            return self.tables.blueSamZonesPerStage[stageName] or {}
        end

        ---@param self table
        ---@param samZone string
        ---@return table
        o.getBlueSamGroupsInZone = function(self, samZone)
            return self.tables.samUnitsPerSamZone[samZone] or {}
        end

        o.getRedGroupsAtAirbase = function(self, airbaseId)
            local baseId = tostring(airbaseId)
            return self.tables.redAirbaseGroupsPerAirbase[baseId] or {}
        end

        o.getBlueGroupsAtAirbase = function(self, airbaseId)
            local baseId = tostring(airbaseId)
            return self.tables.blueAirbaseGroupsPerAirbase[baseId] or {}
        end

        o.getMiscGroupsAtStage = function(self, stageName)
            return self.tables.miscGroupsInStages[stageName] or {}
        end

        ---comment
        ---@param self table
        ---@return integer|nil
        o.GetNewMissionCode = function(self)
            local code = nil
            local tries = 0
            while code == nil and tries < 10 do
                local random = math.random(1000, 9999)
                if self.tables.missionCodes[random] == nil then
                    code = random
                end
                tries = tries + 1
            end
            return code

            --[[
                TODO: What to do when there's no random possible
            ]]
        end

        do -- LOG STATE
            Logger:info("initiated the database with amount of zones: ")
            Logger:info("Stages:            " .. Spearhead.Util.tableLength(o.tables.stage_zones))
            Logger:info("Missions:          " .. Spearhead.Util.tableLength(o.tables.mission_zones))
            Logger:info("Random Missions:   " .. Spearhead.Util.tableLength(o.tables.random_mission_zones))
            Logger:info("Farps:             " .. Spearhead.Util.tableLength(o.tables.farp_zones))
            Logger:info("Airbases:          " .. Spearhead.Util.tableLength(o.tables.airbasesPerStage))
            Logger:info("RedAirbase Groups: " .. Spearhead.Util.tableLength(o.tables.redAirbaseGroupsPerAirbase["21"]))


            for _, missionZone in pairs(o.tables.mission_zones) do
                if o.tables.descriptions[missionZone] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " ..
                    missionZone .. " does not have a briefing")
                end
            end

            for _, randomMission in pairs(o.tables.random_mission_zones) do
                if o.tables.descriptions[randomMission] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " ..
                    randomMission .. " does not have a briefing")
                end
            end
        end
        singleton = o
        return o
    end


Spearhead.DB = SpearheadDB
