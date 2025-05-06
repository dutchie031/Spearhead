
---@class DatabaseTables
---@field AllZoneNames Array<string> All Zone Names
---@field StageZoneNames Array<string> All Stage Zone Names
---@field StageZones table<string, StageZoneData> table<StageZoneName, StageZoneData>
---@field MissionZones Array<string> All Mission Zone Names
---@field RandomMissionZones Array<string> All Random mission names
---@field MissionZonesLocations table<string, Vec2> All Mission Zone Locations
---@field StageZonesByNumber table<string, Array<string>> Stage zones grouped by index number
---@field AllFarpZones Array<string>
---@field FarpIdsInFarpZones table<string, Array<integer>> farp pad Id's in farp zones.
---@field CapRoutes Array<string> All Cap route zone names
---@field CapDataPerStageNumber table<integer, CapData> table<StageNumber, table>
---@field CarrierRouteZones Array<string> All Carrier routes zones
---@field BlueSams Array<string> All blue sam zones
---@field DescriptionsByMission table<string,string> table<ZoneName, Description>
---@field AirbaseDataPerAirfield table<string, AirbaseData>
---@field BlueSamDataPerZone table<string, BlueSamData>
---@field MissionZoneData table<string, MissionZoneData>
---@field FarpZoneData table<string,FarpZoneData>
---@field missionCodes table<string, boolean> 

---@class CapData
---@field routes Array<CapRoute>
---@field current integer

---@class CapRoute 
---@field point1 Vec3
---@field point2 Vec3?

---@class StageZoneData
---@field StageZoneName string
---@field AirbaseNames Array<string>
---@field FarpZones Array<string>
---@field MissionZones Array<string>
---@field RandomMissionZones Array<string>
---@field StageIndex string
---@field BlueSamZones Array<string>
---@field MiscGroups Array<string>

---@class AirbaseData
---@field CapGroups Array<string>
---@field RedGroups Array<string>
---@field BlueGroups Array<string>

---@class BlueSamData
---@field Groups Array<string>

---@class MissionZoneData
---@field Groups Array<string>

---@class MissionData
---@field Groups Array<string>

---@class FarpZoneData
---@field Groups Array<string>

---@class Database
---@field private _tables DatabaseTables
---@field private _logger Logger 
local Database = {}

---comment
---@param Logger Logger
---@return Database
function Database.New(Logger)
    
    ---@type DatabaseTables
    local tables = {
        AllZoneNames = {},
        BlueSams = {},
        CapRoutes = {},
        CapDataPerStageNumber = {},
        CarrierRouteZones = {},
        DescriptionsByMission = {},
        FarpIdsInFarpZones = {},
        MissionZones = {},
        MissionZonesLocations = {},
        StageZoneNames = {},
        RandomMissionZones = {},
        StageZones = {},
        StageZonesByNumber = {},
        AllFarpZones = {},
        AirbaseDataPerAirfield = {},
        BlueSamDataPerZone = {},
        MissionZoneData = {},
        FarpZoneData = {},
        missionCodes = {}
    }

    Database.__index = Database
    local self = setmetatable({}, Database)

    self._logger = Logger
    self._tables = tables

    self._logger:debug("Initiating tables")

    do -- INIT ZONE TABLES
        for zone_ind, zone_data in pairs(Spearhead.DcsUtil.__trigger_zones) do
            local zone_name = zone_data.name
            
            ---@type Vec2
            local zoneLocation = { x = zone_data.location.x, y = zone_data.location.y }

            local split_string = Spearhead.Util.split_string(zone_name, "_")
            table.insert(self._tables.AllZoneNames, zone_name)

            if string.lower(split_string[1]) == "missionstage" then
                table.insert(self._tables.StageZoneNames, zone_name)
                if split_string[2] then
                    local stringified = tostring(split_string[2]) or "unknown"
                    if self._tables.StageZonesByNumber[stringified] == nil then
                        self._tables.StageZonesByNumber[stringified] = {}
                    end
                    table.insert(self._tables.StageZonesByNumber[stringified], zone_name)

                    ---@type StageZoneData
                    local stageData = {
                        StageZoneName = zone_name,
                        StageIndex = stringified,
                        AirbaseNames = {},
                        BlueSamZones = {},
                        FarpZones = {},
                        MissionZones = {},
                        RandomMissionZones = {},
                        MiscGroups = {}
                    }
                    self._tables.StageZones[zone_name] = stageData
                end
            end

            if string.lower(split_string[1]) == "waitingstage" then
                table.insert(self._tables.StageZoneNames, zone_name)
            end

            if string.lower(split_string[1]) == "mission" then
                table.insert(self._tables.MissionZones, zone_name)
                self._tables.MissionZonesLocations[zone_name] = zoneLocation
            end

            if string.lower(split_string[1]) == "randommission" then
                table.insert(self._tables.RandomMissionZones, zone_name)
                self._tables.MissionZonesLocations[zone_name] = zoneLocation
            end

            if string.lower(split_string[1]) == "farp" then
                table.insert(self._tables.AllFarpZones, zone_name)
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

    self._logger:debug("initiated zone tables, continuing with descriptions")
    do --load markers
        if env.mission.drawings and env.mission.drawings.layers then
            for i, layer in pairs(env.mission.drawings.layers) do
                if string.lower(layer.name) == "author" then
                    for key, layer_object in pairs(layer.objects) do

                        if Spearhead.Util.startswith(layer_object.name,  "stagebriefing", true) then
                            --[[
                                TODO: Stage Briefings
                            ]]
                        else
                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY, self._tables.MissionZones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    self._tables.DescriptionsByMission[name] = layer_object.text
                                end
                            end

                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY,
                                self._tables.RandomMissionZones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    self._tables.DescriptionsByMission[name] = layer_object.text
                                end
                            end
                        end

                        
                    end
                end
            end
        end
    end

    for _, stageZoneName in pairs(self._tables.StageZoneNames) do
        local stageData = self._tables.StageZones[stageZoneName]
        if stageData then

            -- fill blue sams
            for _, blueSamStageName in pairs(self._tables.BlueSams) do
                if Spearhead.DcsUtil.isZoneInZone(blueSamStageName, stageZoneName) == true then
                    table.insert(stageData.BlueSamZones, blueSamStageName)
                end
            end

            -- fill missions
            for key, missionZone in pairs(self._tables.MissionZones) do
                if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZoneName) == true then
                    table.insert(stageData.MissionZones, missionZone)
                end
            end

            -- fill random missions
            for key, missionZone in pairs(self._tables.RandomMissionZones) do
                if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZoneName) == true then
                    table.insert(stageData.RandomMissionZones, missionZone)
                end
            end

            -- fill airbases
            for _, airbase in pairs(world.getAirbases()) do
                local point = airbase:getPoint()
                
                if Spearhead.DcsUtil.isPositionInZone(point.x, point.z, stageZoneName)  == true then
                    if airbase:getDesc().category == 0 then
                        table.insert(stageData.AirbaseNames, airbase:getName())
                    elseif airbase:getDesc().category == 1 then
                        -- farp
                        --[[
                            TODO: FARP ZONES FILL
                        ]]
                    end
                end
            end

            --- fill farp zones
            for _, farpZoneName in pairs(self._tables.AllFarpZones) do
                if Spearhead.DcsUtil.isZoneInZone(farpZoneName, stageZoneName) then
                    table.insert(stageData.FarpZones, farpZoneName)
                end
            end

            for _, missionZone in pairs(self._tables.MissionZones) do
                if self._tables.DescriptionsByMission[missionZone] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " .. missionZone .. " does not have a briefing")
                end
            end

            for _, missionZone in pairs(self._tables.RandomMissionZones) do
                if self._tables.DescriptionsByMission[missionZone] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " .. missionZone .. " does not have a briefing")
                end
            end

        end
    end
    
    
    ---@private
    ---@param baseName string
    ---@return AirbaseData
    function Database:getOrCreateAirbaseData(baseName)
        local baseData = self._tables.AirbaseDataPerAirfield[baseName]
        if baseData == nil then
            baseData = {
                CapGroups = {},
                RedGroups = {},
                BlueGroups = {}
            }
            self._tables.AirbaseDataPerAirfield[baseName] = baseData
        end
        return baseData
    end

    

    self:loadCapUnits()
    self:loadBlueSamUnits()
    self:loadMissionzoneUnits()
    self:loadRandomMissionzoneUnits()
    self:loadFarpGroups()
    self:loadAirbaseGroups()
    self:loadMiscGroupsInStages()

   
    for _, zoneData in pairs(self._tables.StageZones) do

        local number = zoneData.StageIndex

        for _, cap_route_zone in pairs(self._tables.CapRoutes) do
            if Spearhead.DcsUtil.isZoneInZone(cap_route_zone, zoneData.StageZoneName) == true then
                local zone = Spearhead.DcsUtil.getZoneByName(cap_route_zone)
                if zone then
                    
                    ---@type CapData
                    local capData = self._tables.CapDataPerStageNumber[number]
                    if capData == nil then
                        capData = {
                            routes = {},
                            current = 0
                        }
                        self._tables.CapDataPerStageNumber[number] = capData
                    end
                    

                    if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                        table.insert(capData.routes, { point1 = { x = zone.location.x, z = zone.location.y, y = 0 }, point2 = nil })
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
                            table.insert(capData.routes,
                                {
                                    point1 = { x = biggestA.x, z = biggestA.y },
                                    point2 = { x = biggestB.x, z = biggestB.y }
                                })
                        end
                    end
                end
            end
        end
    end

    self._logger:info("initiated the database with amount of zones: ")
    self._logger:info("Stages:            " .. Spearhead.Util.tableLength(self._tables.StageZones))
    self._logger:info("Total Missions:    " .. Spearhead.Util.tableLength(self._tables.MissionZoneData))
    self._logger:info("Random Missions:   " .. Spearhead.Util.tableLength(self._tables.RandomMissionZones))
    self._logger:info("Farps:             " .. Spearhead.Util.tableLength(self._tables.AllFarpZones))
    self._logger:info("Airbases:          " .. Spearhead.Util.tableLength(self._tables.AirbaseDataPerAirfield))


    return self

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

---@private
function Database:loadCapUnits()
    local all_groups = getAvailableCAPGroups()
    local airbases = world.getAirbases()
    for _, airbase in pairs(airbases) do
        local baseId = airbase:getID()
        local point = airbase:getPoint()
        local zone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or { x = point.x, z = point.z, radius = 4000 }

        local baseData = self:getOrCreateAirbaseData(airbase:getName())
        local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, zone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(baseData.CapGroups, groupName)
        end

        self._tables.AirbaseDataPerAirfield[airbase:getName()] = baseData
    end
end

---@private
function Database:loadBlueSamUnits()
    local all_groups = Spearhead.DcsUtil.getAllGroupNames()
    for _, blueSamZone in pairs(self._tables.BlueSams) do
        self._tables.BlueSamDataPerZone[blueSamZone] = {
            Groups = {}
        }
        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, blueSamZone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(self._tables.BlueSamDataPerZone[blueSamZone].Groups, groupName)
        end
    end
end

---@private
function Database:loadMissionzoneUnits()
    local all_groups = getAvailableGroups()
    for _, missionZoneName in pairs(self._tables.MissionZones) do
        self._tables.MissionZoneData[missionZoneName] = {
            Groups = {}
        }

        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(self._tables.MissionZoneData[missionZoneName].Groups, groupName)
        end
    end
end

---@private
function Database:loadRandomMissionzoneUnits()
    local all_groups = getAvailableGroups()
    for _, missionZoneName in pairs(self._tables.RandomMissionZones) do
        self._tables.MissionZoneData[missionZoneName] = {
            Groups = {}
        }
        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(self._tables.MissionZoneData[missionZoneName].Groups, groupName)
        end
    end
end

---@private
function Database:loadFarpGroups()
    local all_groups = getAvailableGroups()
    for _, farpZone in pairs(self._tables.AllFarpZones) do
        self._tables.FarpZoneData[farpZone] = {
            Groups = {}
        }

        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, farpZone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(self._tables.FarpZoneData[farpZone].Groups, groupName)
        end
    end
end

function Database:loadAirbaseGroups()

    local all_groups = getAvailableGroups()
    for _, stageZone in pairs(self._tables.StageZones) do
        
        for _, baseName in pairs(stageZone.AirbaseNames) do
            local base = Airbase.getByName(baseName)

            if base then
                local basedata = self:getOrCreateAirbaseData(baseName)
                local baseId = base:getID()
                local point = base:getPoint()
                local airbaseZone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or { x = point.x, z = point.z, radius = 4000 }

                if airbaseZone and base:getDesc().category == Airbase.Category.AIRDROME then
                    local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, airbaseZone)
                    for _, groupName in pairs(groups) do
                        if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                            local object = StaticObject.getByName(groupName)
                            if object then
                                if object:getCoalition() == coalition.side.RED then
                                    table.insert(basedata.RedGroups, groupName)
                                    is_group_taken[groupName] = true
                                elseif object:getCoalition() == coalition.side.BLUE then
                                    table.insert(basedata.BlueGroups, groupName)
                                    is_group_taken[groupName] = true
                                end
                            end
                        else
                            local group = Group.getByName(groupName)
                            if group then
                                if group:getCoalition() == coalition.side.RED then
                                    table.insert(basedata.RedGroups, groupName)
                                    is_group_taken[groupName] = true
                                elseif group:getCoalition() == coalition.side.BLUE then
                                    table.insert(basedata.BlueGroups, groupName)
                                    is_group_taken[groupName] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---@private
function Database:loadMiscGroupsInStages()
    local all_groups = getAvailableGroups()
    for _, stageZone in pairs(self._tables.StageZones) do
        stageZone.MiscGroups = {}

        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, stageZone.StageZoneName)
        for _, groupName in pairs(groups) do
            if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                local object = StaticObject.getByName(groupName)
                if object and object:getCoalition() ~= coalition.side.NEUTRAL then
                    is_group_taken[groupName] = true
                    table.insert(stageZone.MiscGroups, groupName)
                end
            else
                local group = Group.getByName(groupName)
                if group and group:getCoalition() ~= coalition.side.NEUTRAL then
                    is_group_taken[groupName] = true
                    table.insert(stageZone.MiscGroups, groupName)
                end
            end
        end
    end
end


function Database:GetDescriptionForMission(missionZoneName)
    return self._tables.DescriptionsByMission[missionZoneName]
end

---comment
---@param missionZoneName any
---@return Vec2?
function Database:GetLocationForMissionZone(missionZoneName)
    return self._tables.MissionZonesLocations[missionZoneName]
end

function Database:getCapRouteInZone(stageNumber, baseId)
    local stageNumber = tostring(stageNumber) or "nothing"
    local routeData = self._tables.CapDataPerStageNumber[stageNumber]
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
        local stageZoneName = Spearhead.Util.randomFromList(self._tables.StageZonesByNumber[stageNumber]) or
        "none"
        local stagezone = Spearhead.DcsUtil.getZoneByName(stageZoneName)
        if stagezone then
            local base = Spearhead.DcsUtil.getAirbaseById(baseId)
            if base then
                local closest = nil
                if stagezone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                    closest = GetClosestPointOnCircle({ x = stagezone.location.x, z = stagezone.location.y }, stagezone.radius,
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
                    return { point1 = closest, point2 = { x = stagezone.location.x, z = stagezone.location.y } }
                else
                    return { point1 = { x = stagezone.location.x, z = stagezone.location.y }, point2 = closest }
                end
            end
        end
    end
end


---@return Array<string> result a  list of stage zone names
function Database:getStagezoneNames()
    return self._tables.StageZoneNames
end

function Database:getCarrierRouteZones()
    return self._tables.CarrierRouteZones
end

---@return Array<string>
function Database:getMissionsForStage(stagename)
    local stageZone = self._tables.StageZones[stagename]
    if not stageZone then return {} end
    return stageZone.MissionZones
end

---@return Array<string>
function Database:getRandomMissionsForStage(stagename)
    local stageZone = self._tables.StageZones[stagename]
    if not stageZone then return {} end
    return stageZone.RandomMissionZones
end

---@return Array<string>
function Database:getGroupsForMissionZone(missionZoneName)
    local missionZoneData = self._tables.MissionZoneData[missionZoneName]
    if not missionZoneData then return {} end
    return missionZoneData.Groups
end

---@return string?
function Database:getMissionBriefingForMissionZone(missionZoneName)
    return self._tables.DescriptionsByMission[missionZoneName]
end

---@param stageName string
---@return table result airbase Names
function Database:getAirbaseNamesInStage(stageName)
    
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end

    return stageData.AirbaseNames or {}
end


---@param airbaseName string
---@return Array<string>
function Database:getCapGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return {} end
    return airbaseData.CapGroups
end

---@param stageName string
---@return Array<string>
function Database:getBlueSamsInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end
    return stageData.BlueSamZones
end

---@param samZone string
---@return Array<string>
function Database:getBlueSamGroupsInZone(samZone)
    local blueSamData = self._tables.BlueSamDataPerZone[samZone]
    if not blueSamData then return {} end
    return blueSamData.Groups
end

---@param airbaseName string
---@return Array<string>
function Database:getRedGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return {} end
    return airbaseData.RedGroups
end

---@param airbaseName string
---@return Array<string>
function Database:getBlueGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return {} end
    return airbaseData.BlueGroups
end

function Database:getMiscGroupsAtStage(stageName)
    local stageZone = self._tables.StageZones[stageName]
    if not stageZone then return {} end
    return stageZone.MiscGroups
end

---@return integer|nil
function Database:GetNewMissionCode()
    local code = nil
    local tries = 0
    while code == nil and tries < 10 do
        local random = math.random(1000, 9999)
        if self._tables.missionCodes[random] == nil then
            code = random
        end
        tries = tries + 1
    end
    return code

    --[[
        TODO: What to do when there's no random possible
    ]]
end



Spearhead.DB = Database
