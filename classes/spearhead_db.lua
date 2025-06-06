---@class DatabaseTables
---@field AllZoneNames Array<string> All Zone Names
---@field StageZoneNames Array<string> All Stage Zone Names
---@field StageZones table<string, StageZoneData> table<StageZoneName, StageZoneData>
---@field MissionZones Array<string> All Mission Zone Names
---@field RandomMissionZones Array<string> All Random mission names
---@field MissionZonesLocations table<string, Vec2> All Mission Zone Locations
---@field StageZonesByNumber table<string, Array<string>> Stage zones grouped by index number
---@field AllFarpZones Array<string>
---@field AllCapRoutes Array<string> All Cap route zone names
---@field AllInterceptZones Array<string> All intercept zones
---@field capZonesByCapZoneID table<string, CapRoute>
---@field interceptZonesByZoneID table<string, Array<SpearheadTriggerZone>>
---@field CarrierRouteZones Array<string> All Carrier routes zones
---@field BlueSams Array<string> All blue sam zones
---@field SupplyHubZones Array<string> All supply hub zones
---@field MissionAnnotations table<string, MissionAnnotations> table<ZoneName, MissionAnnotations>
---@field AirbaseDataPerAirfield table<string, AirbaseData>
---@field BlueSamDataPerZone table<string, BlueSamData>
---@field MissionZoneData table<string, MissionZoneData>
---@field FarpZoneData table<string,FarpZoneData>
---@field missionCodes table<string, boolean>


---@class CapRoute
---@field zones Array<SpearheadTriggerZone>
---@field current number

---@class MissionAnnotations
---@field description string?
---@field dependsOn Array<string>
---@field completeAt number?

---@class StageZoneData
---@field StageZoneName string
---@field AirbaseNames Array<string>
---@field FarpZones Array<string>
---@field MissionZones Array<string>
---@field RandomMissionZones Array<string>
---@field StageIndex string
---@field BlueSamZones Array<string>
---@field SupplyHubZones Array<string>
---@field SupplyHubZonesInFarp table<string, string>
---@field MiscGroups Array<string>

---@class AirbaseData
---@field CapGroups Array<string>
---@field SweepGroups Array<string>
---@field InterceptGroups Array<string>
---@field RedGroups Array<string>
---@field BlueGroups Array<string>
---@field supplyHubNames Array<string>
---@field buildingKilos number?

---@class BlueSamData
---@field groups Array<string>
---@field buildingKilos number?

---@class MissionZoneData
---@field RedGroups Array<string>
---@field BlueGroups Array<string>

---@class MissionData
---@field Groups Array<string>

---@class FarpZoneData
---@field groups Array<string>
---@field padNames Array<string>
---@field buildingKilos number?
---@field supplyHubNames Array<string>

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
        AllCapRoutes = {},
        capZonesByCapZoneID = {},
        AllInterceptZones = {},
        interceptZonesByZoneID = {},
        CarrierRouteZones = {},
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
        missionCodes = {},
        MissionAnnotations = {},
        SupplyHubZones = {}
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
                        MiscGroups = {},
                        SupplyHubZones = {},
                        SupplyHubZonesInFarp = {}
                    }
                    self._tables.StageZones[zone_name] = stageData
                end
            end

            local lowered = string.lower(split_string[1])

            if lowered == "waitingstage" then
                table.insert(self._tables.StageZoneNames, zone_name)
            end

            if lowered == "mission" then
                table.insert(self._tables.MissionZones, zone_name)
                self._tables.MissionZonesLocations[zone_name] = zoneLocation
            end

            if lowered == "randommission" then
                table.insert(self._tables.RandomMissionZones, zone_name)
                self._tables.MissionZonesLocations[zone_name] = zoneLocation
            end

            if lowered == "farp" then
                table.insert(self._tables.AllFarpZones, zone_name)
            end

            if lowered == "caproute" then
                table.insert(self._tables.AllCapRoutes, zone_name)
            end

            if lowered == "interceptzone" then
                table.insert(self._tables.AllInterceptZones, zone_name)
            end

            if lowered == "carrierroute" then
                table.insert(self._tables.CarrierRouteZones, zone_name)
            end

            if lowered == "bluesam" then
                table.insert(self._tables.BlueSams, zone_name)
            end

            if lowered == "supplyhub" then
                table.insert(self._tables.SupplyHubZones, zone_name)
            end
        end
    end

    self._logger:debug("initiated zone tables, continuing with descriptions")
    do --load markers
        if env.mission.drawings and env.mission.drawings.layers then
            for i, layer in pairs(env.mission.drawings.layers) do
                if string.lower(layer.name) == "author" then
                    for key, layer_object in pairs(layer.objects) do
                        if Spearhead.Util.startswith(string.lower(layer_object.name), "buildable", true) == true then
                            local blueSamData = self:getBlueSamDataForDrawLayer(layer_object)
                            if blueSamData then
                                local number = tonumber(layer_object.text)
                                blueSamData.buildingKilos = number
                            end

                            local farpData = self:getFarpDataForDrawLayer(layer_object)
                            if farpData then
                                local number = tonumber(layer_object.text)
                                farpData.buildingKilos = number
                            end

                            local airbaseData = self:getAirbaseDataForDrawLayer(layer_object)
                            if airbaseData then
                                self._logger:debug("found airbase data for " .. layer_object.name)
                                local number = tonumber(layer_object.text)
                                airbaseData.buildingKilos = number
                            end
                        elseif Spearhead.Util.startswith(string.lower(layer_object.name), "completeat", true) == true then
                            local annotationData = self:getMissionMetaDataForDrawLayer(layer_object)
                            if annotationData then
                                local number = tonumber(layer_object.text)
                                if number and number > 1 then
                                    number = number / 100
                                end
                                annotationData.completeAt = number
                            end
                        elseif Spearhead.Util.startswith(string.lower(layer_object.name), "dependson", true) == true then
                            local annotationData = self:getMissionMetaDataForDrawLayer(layer_object)
                            if annotationData then
                                table.insert(annotationData.dependsOn, layer_object.text)
                            end
                        elseif Spearhead.Util.startswith(layer_object.name, "stagebriefing", true) == true then
                            --[[
                                TODO: Stage Briefings
                            ]]
                        else
                            local annotationData = self:getMissionMetaDataForDrawLayer(layer_object)
                            if annotationData then
                                annotationData.description = layer_object.text
                            end
                        end
                    end
                end
            end
        end
    end

    ---@type table<string, boolean>
    local availableSupplyHubs = {}
    for _, supplyHubZoneName in pairs(self._tables.SupplyHubZones) do
        availableSupplyHubs[supplyHubZoneName] = true
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

            --- fill farp zones
            for _, farpZoneName in pairs(self._tables.AllFarpZones) do
                if Spearhead.DcsUtil.isZoneInZone(farpZoneName, stageZoneName) then
                    table.insert(stageData.FarpZones, farpZoneName)

                    for hubZoneName, available in pairs(availableSupplyHubs) do
                        if available == true and Spearhead.DcsUtil.isZoneInZone(hubZoneName, farpZoneName) == true then
                            local farpZoneData = self:getOrCreateFarpDataForZone(farpZoneName)
                            if farpZoneData then
                                table.insert(farpZoneData.supplyHubNames, hubZoneName)
                                availableSupplyHubs[hubZoneName] = false
                            end
                        end
                    end
                end
            end

            -- fill airbases
            for _, airbase in pairs(world.getAirbases()) do
                local point = airbase:getPoint()

                if Spearhead.DcsUtil.isPositionInZone(point.x, point.z, stageZoneName) == true then
                    if airbase:getDesc().category == 0 then
                        table.insert(stageData.AirbaseNames, airbase:getName())

                        local airbaseZone = Spearhead.DcsUtil.getAirbaseZoneByName(airbase:getName())
                        for hubZoneName, available in pairs(availableSupplyHubs) do
                            local zone = Spearhead.DcsUtil.getZoneByName(hubZoneName)
                            if zone and airbaseZone then
                                if available == true and Spearhead.Util.is2dPointInZone(zone.location, airbaseZone) == true then
                                    local airbaseData = self:getOrCreateAirbaseData(airbase:getName())
                                    if airbaseData then
                                        table.insert(airbaseData.supplyHubNames, hubZoneName)
                                        availableSupplyHubs[hubZoneName] = false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- fill supply hubs
            for supplyHubZone, available in pairs(availableSupplyHubs) do
                if available == true and Spearhead.DcsUtil.isZoneInZone(supplyHubZone, stageZoneName) == true then
                    table.insert(stageData.SupplyHubZones, supplyHubZone)
                end
            end

            for _, farpZoneName in pairs(stageData.FarpZones) do
                for _, supplyHubZone in pairs(self._tables.SupplyHubZones) do
                    if Spearhead.DcsUtil.isZoneInZone(supplyHubZone, farpZoneName) == true then
                        stageData.SupplyHubZonesInFarp[supplyHubZone] = farpZoneName
                    end
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
        end
    end

    for _, missionZone in pairs(self._tables.MissionZones) do
        if self._tables.MissionAnnotations[missionZone] == nil or self._tables.MissionAnnotations[missionZone].description == nil then
            Spearhead.AddMissionEditorWarning("Mission with zonename: " .. missionZone .. " does not have a briefing")
        end
    end

    for _, missionZone in pairs(self._tables.RandomMissionZones) do
        if self._tables.MissionAnnotations[missionZone] == nil or self._tables.MissionAnnotations[missionZone].description == nil then
            Spearhead.AddMissionEditorWarning("Mission with zonename: " .. missionZone .. " does not have a briefing")
        end
    end

    for _, farpZoneName in pairs(self._tables.AllFarpZones) do
        for _, airbase in pairs(world.getAirbases()) do
            if airbase:getDesc().category == Airbase.Category.HELIPAD then
                local name = airbase:getName()

                if self._tables.FarpZoneData[farpZoneName] == nil then
                    self._tables.FarpZoneData[farpZoneName] = {
                        groups = {},
                        padNames = {},
                        supplyHubNames = {}
                    }
                end
                local position = airbase:getPoint()
                if Spearhead.DcsUtil.isPositionInZone(position.x, position.z, farpZoneName) == true then
                    table.insert(self._tables.FarpZoneData[farpZoneName].padNames, name)
                end
            end
        end
    end


    self:initAvailableUnits()
    self:loadCapUnits()
    self:loadBlueSamUnits()
    self:loadMissionzoneUnits()
    self:loadRandomMissionzoneUnits()
    self:loadFarpGroups()
    self:loadAirbaseGroups()
    self:loadMiscGroupsInStages()


    for _, cap_route_zone in pairs(self._tables.AllCapRoutes) do
        local split = Spearhead.Util.split_string(cap_route_zone, "_")
        local zoneID = split[2]

        if zoneID then
            if tables.capZonesByCapZoneID[zoneID] == nil then
                tables.capZonesByCapZoneID[zoneID] = {
                    zones = {},
                    current = 1
                }
            end

            local zone = Spearhead.DcsUtil.getZoneByName(cap_route_zone)
            if zone then
                table.insert(tables.capZonesByCapZoneID[zoneID].zones, zone)
            end
        end
    end

    for _, interceptZone in pairs(self._tables.AllCapRoutes) do
        local split = Spearhead.Util.split_string(interceptZone, "_")
        local zoneID = split[2]

        if zoneID then
            if tables.interceptZonesByZoneID[zoneID] == nil then
                tables.interceptZonesByZoneID[zoneID] = {}
            end

            local zone = Spearhead.DcsUtil.getZoneByName(interceptZone)
            if zone then
                table.insert(tables.interceptZonesByZoneID[zoneID], zone)
            end
        end
    end

    local totalUnits = 0
    local missions = 0
    for _, data in pairs(self._tables.MissionZoneData) do
        missions = missions + 1
        for _, groupName in pairs(data.RedGroups) do
            local group = Group.getByName(groupName)
            if group then
                totalUnits = totalUnits + group:getInitialSize()
            end
        end

        for _, groupName in pairs(data.BlueGroups) do
            local group = Group.getByName(groupName)
            if group then
                totalUnits = totalUnits + group:getInitialSize()
            end
        end
    end

    if missions == 0 then missions = 1 end

    self._logger:info("initiated the database with amount of zones: ")
    self._logger:info("Stages:            " .. Spearhead.Util.tableLength(self._tables.StageZones))
    self._logger:info("Total Missions:    " .. Spearhead.Util.tableLength(self._tables.MissionZoneData))
    self._logger:info("Average units per mission: " .. totalUnits / missions)
    self._logger:info("Random Missions:   " .. Spearhead.Util.tableLength(self._tables.RandomMissionZones))
    self._logger:info("Farps:             " .. Spearhead.Util.tableLength(self._tables.AllFarpZones))
    self._logger:info("Airbases:          " .. Spearhead.Util.tableLength(self._tables.AirbaseDataPerAirfield))


    return self
end

local is_group_taken = {}

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
function Database:initAvailableUnits()
    do
        local all_groups = Spearhead.DcsUtil.getAllGroupNames()
        for _, value in pairs(all_groups) do
            is_group_taken[value] = false
        end
    end
end

---comment
---@private
---@param layer_object table
---@return BlueSamData?
function Database:getBlueSamDataForDrawLayer(layer_object)
    for _, zonename in pairs(self._tables.BlueSams) do
        if Spearhead.DcsUtil.isPositionInZone(layer_object.mapX, layer_object.mapY, zonename) == true then
            return self:getOrCreateBlueSamDataForZone(zonename)
        end
    end
    return nil
end

---@private
---@param layer_object table
---@return FarpZoneData?
function Database:getFarpDataForDrawLayer(layer_object)
    for _, zonename in pairs(self._tables.AllFarpZones) do
        if Spearhead.DcsUtil.isPositionInZone(layer_object.mapX, layer_object.mapY, zonename) == true then
            return self:getOrCreateFarpDataForZone(zonename)
        end
    end
    return nil
end

---comment
---@param layer_object table
---@return AirbaseData?
function Database:getAirbaseDataForDrawLayer(layer_object)
    for _, airbase in pairs(world.getAirbases()) do
        local zone = Spearhead.DcsUtil.getAirbaseZoneByName(airbase:getName())

        if zone and Spearhead.Util.is2dPointInZone({ x = layer_object.mapX, y = layer_object.mapY }, zone) == true then
            return self:getOrCreateAirbaseData(airbase:getName())
        end
    end

    return nil
end

---@private
function Database:getOrCreateBlueSamDataForZone(zoneName)
    local blueSamData = self._tables.BlueSamDataPerZone[zoneName]
    if blueSamData == nil then
        blueSamData = {
            groups = {},
            buildingCrates = nil
        }
        self._tables.BlueSamDataPerZone[zoneName] = blueSamData
    end
    return blueSamData
end

---@private
function Database:getOrCreateFarpDataForZone(zoneName)
    local farpData = self._tables.FarpZoneData[zoneName]
    if farpData == nil then
        farpData = {
            padNames = {},
            groups = {},
            buildingCrates = nil,
            supplyHubNames = {}
        }
        self._tables.FarpZoneData[zoneName] = farpData
    end
    return farpData
end

---@private
---@param baseName string
---@return AirbaseData
function Database:getOrCreateAirbaseData(baseName)
    local baseData = self._tables.AirbaseDataPerAirfield[baseName]
    if baseData == nil then
        baseData = {
            CapGroups = {},
            InterceptGroups = {},
            SweepGroups = {},
            RedGroups = {},
            BlueGroups = {},
            supplyHubNames = {}
        }
        self._tables.AirbaseDataPerAirfield[baseName] = baseData
    end
    return baseData
end

---@private
---@param layer_object table
---@return MissionAnnotations?
function Database:getMissionMetaDataForDrawLayer(layer_object)
    for _, zonename in pairs(self._tables.MissionZones) do
        if Spearhead.DcsUtil.isPositionInZone(layer_object.mapX, layer_object.mapY, zonename) == true then
            if self._tables.MissionAnnotations[zonename] == nil then
                self._tables.MissionAnnotations[zonename] = {
                    description = nil,
                    dependsOn = {}
                }
            end

            return self._tables.MissionAnnotations[zonename]
        end
    end

    for _, zonename in pairs(self._tables.RandomMissionZones) do
        if Spearhead.DcsUtil.isPositionInZone(layer_object.mapX, layer_object.mapY, zonename) == true then
            if self._tables.MissionAnnotations[zonename] == nil then
                self._tables.MissionAnnotations[zonename] = {
                    description = nil,
                    dependsOn = {}
                }
            end

            return self._tables.MissionAnnotations[zonename]
        end
    end
    return nil
end

---@private
function Database:loadCapUnits()
    local all_groups = getAvailableCAPGroups()
    local airbases = world.getAirbases()
    for _, airbase in pairs(airbases) do
        local point = airbase:getPoint()

        ---@type SpearheadTriggerZone?
        local zone = Spearhead.DcsUtil.getAirbaseZoneByName(airbase:getName())

        if zone == nil then
            zone = {
                location = { x = point.x, y = point.z },
                radius = 4000,
                name = "temp_zone",
                verts = {},
                zone_type = "Cilinder"
            }
        end


        local baseData = self:getOrCreateAirbaseData(airbase:getName())
        local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, zone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true

            if Spearhead.Util.startswith(groupName, "CAP_A", true) or Spearhead.Util.startswith(groupName, "CAP_B", true) then
                table.insert(baseData.CapGroups, groupName)
            elseif Spearhead.Util.startswith(groupName, "CAP_I", true) then
                table.insert(baseData.InterceptGroups, groupName)
            elseif Spearhead.Util.startswith(groupName, "CAP_S", true) then
                table.insert(baseData.SweepGroups, groupName)
            end
        end

        self._tables.AirbaseDataPerAirfield[airbase:getName()] = baseData
    end
end

---@private
function Database:loadBlueSamUnits()
    local all_groups = Spearhead.DcsUtil.getAllGroupNames()
    for _, blueSamZone in pairs(self._tables.BlueSams) do
        local samData = self:getOrCreateBlueSamDataForZone(blueSamZone)
        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, blueSamZone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(samData.groups, groupName)
        end
    end
end

---@private
function Database:loadMissionzoneUnits()
    local all_groups = getAvailableGroups()
    for _, missionZoneName in pairs(self._tables.MissionZones) do
        self._tables.MissionZoneData[missionZoneName] = {
            RedGroups = {},
            BlueGroups = {},
        }

        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
        for _, groupName in pairs(groups) do
            if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                local object = StaticObject.getByName(groupName)
                
                if object and object:getCoalition() == coalition.side.RED then
                    table.insert(self._tables.MissionZoneData[missionZoneName].RedGroups, groupName)
                elseif object  then
                    table.insert(self._tables.MissionZoneData[missionZoneName].BlueGroups, groupName)
                end
                
            else
                local group = Group.getByName(groupName)
                if group and group:getCoalition() == coalition.side.RED then
                    table.insert(self._tables.MissionZoneData[missionZoneName].RedGroups, groupName)
                elseif group then
                    table.insert(self._tables.MissionZoneData[missionZoneName].BlueGroups, groupName)
                end
            end
            is_group_taken[groupName] = true
        end
    end
end

---@private
function Database:loadRandomMissionzoneUnits()
    local all_groups = getAvailableGroups()
    for _, missionZoneName in pairs(self._tables.RandomMissionZones) do
        self._tables.MissionZoneData[missionZoneName] = {
            RedGroups = {},
            BlueGroups = {},
        }
        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
        for _, groupName in pairs(groups) do
            if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                local object = StaticObject.getByName(groupName)
                
                if object and object:getCoalition() == coalition.side.RED then
                    table.insert(self._tables.MissionZoneData[missionZoneName].RedGroups, groupName)
                elseif object  then
                    table.insert(self._tables.MissionZoneData[missionZoneName].BlueGroups, groupName)
                end
                
            else
                local group = Group.getByName(groupName)
                if group and group:getCoalition() == coalition.side.RED then
                    table.insert(self._tables.MissionZoneData[missionZoneName].RedGroups, groupName)
                elseif group then
                    table.insert(self._tables.MissionZoneData[missionZoneName].BlueGroups, groupName)
                end
            end
            is_group_taken[groupName] = true
        end
    end
end

---@private
function Database:loadFarpGroups()
    local all_groups = getAvailableGroups()
    for _, farpZone in pairs(self._tables.AllFarpZones) do
        local farpzoneData = self:getOrCreateFarpDataForZone(farpZone)

        local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, farpZone)
        for _, groupName in pairs(groups) do
            is_group_taken[groupName] = true
            table.insert(farpzoneData.groups, groupName)
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
                local point = base:getPoint()
                local airbaseZone = Spearhead.DcsUtil.getAirbaseZoneByName(baseName)

                if airbaseZone == nil then
                    airbaseZone = {
                        location = { x = point.x, y = point.z },
                        radius = 4000,
                        name = "temp_zone",
                        verts = {},
                        zone_type = "Cilinder"
                    }
                end


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

---@return string?
function Database:getMissionBriefingForMissionZone(missionZoneName)
    if not self._tables.MissionAnnotations[missionZoneName] then
        return nil
    end

    return self._tables.MissionAnnotations[missionZoneName].description
end

---@param missionZoneName string
---@return Array<string>
function Database:getMissionDependencies(missionZoneName)
    if not self._tables.MissionAnnotations[missionZoneName] then
        return {}
    end

    return self._tables.MissionAnnotations[missionZoneName].dependsOn
end

---@return number?
function Database:getMissionCompleteAt(missionZoneName)
    if not self._tables.MissionAnnotations[missionZoneName] then
        return nil
    end

    return self._tables.MissionAnnotations[missionZoneName].completeAt
end

---comment
---@param missionZoneName any
---@return Vec2?
function Database:GetLocationForMissionZone(missionZoneName)
    return self._tables.MissionZonesLocations[missionZoneName]
end

---@param zoneID string
---@return SpearheadTriggerZone?
function Database:GetCapZoneForZoneID(zoneID)
    zoneID = tostring(zoneID) or "nothing"

    local capZonesForID = self._tables.capZonesByCapZoneID[zoneID]

    if capZonesForID and capZonesForID.zones then

        local count = Spearhead.Util.tableLength(capZonesForID.zones)
        if count == 0 then
            self._logger:warn("Tried to get cap zone for zoneID: " .. zoneID .. " but cap zones were empty for this ID")
            return nil
        end

        capZonesForID.current = capZonesForID.current + 1
        if Spearhead.Util.tableLength(capZonesForID.zones) < capZonesForID.current then
            capZonesForID.current = 1
        end
        return capZonesForID.zones[capZonesForID.current]
    else
        self._logger:warn("Tried to get cap zone for zoneID: " .. zoneID .. " but no cap zones were found for this ID")
    end

    return nil
end

function Database:GetInterceptZonesForZoneID(zoneID)
    zoneID = tostring(zoneID) or "nothing"

    local interceptZonesForID = self._tables.interceptZonesByZoneID[zoneID]

    if not interceptZonesForID then
        return {}
    end

    return interceptZonesForID
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

---@return MissionZoneData?
function Database:getMissionDataForZone(missionZoneName)
    return self._tables.MissionZoneData[missionZoneName]
end

---@param stageName string
---@return table result airbase Names
function Database:getAirbaseNamesInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end

    return stageData.AirbaseNames or {}
end

function Database:getFarpNamesInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end
    return stageData.FarpZones or {}
end

---@return FarpZoneData?
function Database:getFarpDataForZone(farpZoneName)
    local farpData = self._tables.FarpZoneData[farpZoneName]
    if not farpData then return nil end
    return farpData
end

---@return AirbaseData?
---@param baseName string
function Database:getAirbaseDataForZone(baseName)
    local baseData = self._tables.AirbaseDataPerAirfield[baseName]
    if not baseData then return nil end
    return baseData
end


---@param stageName string
---@return Array<string>
function Database:getBlueSamsInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end
    return stageData.BlueSamZones
end

---@param stageName string
---@return Array<string>
function Database:getSupplyHubsInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end
    return stageData.SupplyHubZones
end

---comment
---@param stageName any
---@param supplyZoneName any
---@return nil
function Database:getFarpDependencyForSupplyHub(stageName, supplyZoneName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return nil end
    return stageData.SupplyHubZonesInFarp[supplyZoneName]
end

---@param samZone string
---@return BlueSamData?
function Database:getBlueSamDataForZone(samZone)
    return self._tables.BlueSamDataPerZone[samZone]
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

if not Spearhead then Spearhead = {} end
Spearhead.DB = Database
