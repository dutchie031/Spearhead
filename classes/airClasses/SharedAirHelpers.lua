if not Spearhead.internal then Spearhead.internal = {} end

if Spearhead.internal.Air == nil then Spearhead.internal.Air = {} end

local logger = Spearhead.LoggerTemplate:new("SharedAirHelpers", Spearhead.LoggerTemplate.LogLevelOptions.INFO)

Spearhead.internal.Air.GroupState = {
    UNSPAWNED = 0,
    READYONRAMP = 1,
    INTRANSIT = 2,
    ONSTATION = 3,
    RTBINTEN = 4,
    RTB = 5,
    DEAD = 6,
    REARMING = 7,
    ESCORTING = 8,
    WAITINGFORESCORT = 9
}



Spearhead.internal.Air.CapGroupType = {
    PRIMARY = 1,
    SECONDARY = 2,
    ESCORT = 3,
}

Spearhead.internal.Air.AttackGroupType = {
    CAS = 1,
    SEAD = 2,
    STRIKE = 3
}

do -- Name Parsers
    ---comment
    ---@param groupName string
    ---@return table? parsedResult { zonesConfig, capGroupType }
    Spearhead.internal.Air.ParseCapGroupName = function(groupName)
        local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then
            local result = {}
            result.zonesConfig = {}

            -- CAP_[1-5]5|[6]6|[7]7_Sukhoi
            -- CAP_[1-5,7]A|[6]7_Sukhoi

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "A" then
                result.capGroupType = Spearhead.internal.Air.CapGroupType.PRIMARY
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "B" then
                configPart = string.sub(configPart, 2, #configPart)
                result.capGroupType = Spearhead.internal.Air.CapGroupType.SECONDARY
            elseif first == "E" then
                configPart = string.sub(configPart, 2, #configPart)
                result.capGroupType = Spearhead.internal.Air.CapGroupType.ESCORT
            elseif first == "[" then
                result.capGroupType = Spearhead.internal.Air.CapGroupType.PRIMARY
            else
                Spearhead.AddMissionEditorWarning("Could not parse the CAP config for group: " .. groupName)
                return nil
            end

            local subsplit = Spearhead.Util.split_string(configPart, "|")
            if subsplit then
                for key, value in pairs(subsplit) do
                    local keySplit = Spearhead.Util.split_string(value, "]")
                    local targetZone = keySplit[2]
                    local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                    local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                    for _, value in pairs(commaSeperated) do
                        local dashSeperated = Spearhead.Util.split_string(value, "-")
                        if Spearhead.Util.tableLength(dashSeperated) > 1 then
                            local from = tonumber(dashSeperated[1])
                            local till = tonumber(dashSeperated[2])

                            for i = from, till do
                                if targetZone == "A" then
                                    result.zonesConfig[tostring(i)] = tostring(i)
                                else
                                    result.zonesConfig[tostring(i)] = tostring(targetZone)
                                end
                            end
                        else
                            if targetZone == "A" then
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(dashSeperated[1])
                            else
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(targetZone)
                            end
                        end
                    end
                end
            end
            return result
        else
            Spearhead.AddMissionEditorWarning("CAP Group with name: " ..
                groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
    end

    ---comment
    ---@param groupName string
    ---@return table? parsedResult { zonesConfig, attackGroupType }
    Spearhead.internal.Air.ParseAttackGroupName = function(groupName)
        local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then
            local result = {}
            result.zonesConfig = {}

            -- CAS_[1-5]5|[6]6|[7]7_Sukhoi
            -- CAS_[1-5,7]A|[6]7_Sukhoi

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "C" then
                result.attackGroupType = Spearhead.internal.Air.AttackGroupType.CAS
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "S" then
                configPart = string.sub(configPart, 2, #configPart)
                result.attackGroupType = Spearhead.internal.Air.AttackGroupType.SEAD
            elseif first == "[" then
                result.attackGroupType = Spearhead.internal.Air.AttackGroupType.CAS
            else
                Spearhead.AddMissionEditorWarning("Could not parse the CAS config for group: " .. groupName)
                return nil
            end

            local subsplit = Spearhead.Util.split_string(configPart, "|")
            if subsplit then
                for key, value in pairs(subsplit) do
                    local keySplit = Spearhead.Util.split_string(value, "]")
                    local targetZone = keySplit[2]
                    local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                    local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                    for _, value in pairs(commaSeperated) do
                        local dashSeperated = Spearhead.Util.split_string(value, "-")
                        if Spearhead.Util.tableLength(dashSeperated) > 1 then
                            local from = tonumber(dashSeperated[1])
                            local till = tonumber(dashSeperated[2])

                            for i = from, till do
                                if targetZone == "A" then
                                    result.zonesConfig[tostring(i)] = tostring(i)
                                else
                                    result.zonesConfig[tostring(i)] = tostring(targetZone)
                                end
                            end
                        else
                            if targetZone == "A" then
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(dashSeperated[1])
                            else
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(targetZone)
                            end
                        end
                    end
                end
            end
            return result
        else
            Spearhead.AddMissionEditorWarning("CAP Group with name: " ..
                groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
    end
end

do  --routes
    if Spearhead.internal.Air.Routing == nil then Spearhead.internal.Air.Routing = {} end

    Spearhead.internal.Air.Routing.GetOrCreateCapRoute = function(database, stageNumber, stageName, baseId)
        local dbPoint = database:getCapRouteInZone(stageNumber)
        if dbPoint then return dbPoint end

        do
            local function GetClosestPointOnCircle(pC, radius, p)
                local vX = p.x - pC.x;
                local vY = p.z - pC.z;
                local magV = math.sqrt(vX * vX + vY * vY);
                local aX = pC.x + vX / magV * radius;
                local aY = pC.z + vY / magV * radius;
                return { x = aX, z = aY }
            end
            local stagezone = Spearhead.DcsUtil.getZoneByName(stageName)
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
                        return { [1] = closest, [2] = { x = stagezone.x, z = stagezone.z } }
                    else
                        return { [1] = { x = stagezone.x, z = stagezone.z }, [2] = closest }
                    end
                end
            end
            return nil
        end
    end

    Spearhead.internal.Air.Routing.GetOrCreateCasRoute = function(casTargetZone, groupName, stageNumber, speed, altitude, baseId, duration)
        local errorMessage = ""
        if casTargetZone then
            local zone = Spearhead.DcsUtil.getZoneByName(casTargetZone)
            if zone ~= nil then
                local task, error = Spearhead.RouteUtil.CreateCasInZoneTask(groupName, {x = zone.x, z = zone.z, y = 0}, zone.radius, baseId, speed, altitude, duration)
                logger:info(task)
                errorMessage = error
                return task
            else
                errorMessage = "Could not get zone with name " .. casTargetZone
            end
        else
            errorMessage = "Could not get zone with for stageNumber " .. stageNumber
        end

        logger:warn("Could not create CasInZoneTasking for group ".. groupName .. " due to: " .. errorMessage)
        return nil
    end
end

do -- bingo settings
    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.BingoSettings == nil then SpearheadConfig.BingoSettings = {} end

    local validProfiles = { ["modern"] = true, ["ww2"] = true }
    local profile = SpearheadConfig.BingoSettings.baseProfile or "modern"
    if validProfiles[profile] ~= true then
        profile = "modern"
    end

    local baseConfig = {}
    baseConfig["fuel"] = 0.2
    baseConfig["noradarmissiles"] = false
    baseConfig["noheatseekingmissiles"] = false
    baseConfig["nobullets"] = false
    baseConfig["noseadmissiles"] = false
    baseConfig["norockets"] = false
    baseConfig["nobombs"] = false

    local CopyBaseConfig = function()
        local config = {}
        for key, value in pairs(baseConfig) do
            config[key] = value
        end
        return config
    end

    local allConfigTable = {}

    local function InsertConfigIntoTable(dictKey, configValues)
        if type(configValues) ~= "table" then return end
        local config = CopyBaseConfig()
        for key, value in pairs(configValues) do
            config[string.lower(key)] = value
        end
        allConfigTable[string.lower(dictKey)] = config
    end

    do -- Default Spearhead configurations
        if profile == "ww2" then
            InsertConfigIntoTable("CAP", {
                ["nobullets"] = true
            })

            InsertConfigIntoTable("ESCORT", {
                ["nobullets"] = true
            })
        else
            InsertConfigIntoTable("CAP", {
                ["noheatseekingmissiles"] = true,
                ["nobullets"] = true
            })

            InsertConfigIntoTable("ESCORT", {
                ["noheatseekingmissiles"] = true,
                ["nobullets"] = true
            })
        end
    end

    do -- Overwrite settings with custom types
        if SpearheadConfig.BingoSettings.CustomProfiles == nil then SpearheadConfig.BingoSettings.CustomProfiles = {} end
        for key, value in pairs(SpearheadConfig.BingoSettings.CustomProfiles) do
            InsertConfigIntoTable(key, value)
        end
    end

    local function GetBingoSetting(groupName, groupType, taskingType)
        groupName = string.lower(groupName)
        if allConfigTable[groupName] then
            return allConfigTable[groupName]
        end

        if groupType and type(groupType) == "string" then
            groupType = string.lower(groupType)
            if allConfigTable[groupType] then
                return allConfigTable[groupType]
            end
        end

        if taskingType and type(taskingType) == "string" then
            taskingType = string.lower(taskingType)
            if allConfigTable[taskingType] then
                return allConfigTable[taskingType]
            end
        end

        return baseConfig
    end

    function Spearhead.internal.Air.IsBingo(groupName, taskingType, fuelOffset)
        return (Spearhead.internal.Air.IsBingoFuel(groupName, taskingType, fuelOffset) or Spearhead.internal.Air.IsBingoWeapons(groupName, taskingType))
    end


    local checkBingoTime = {}
    local lastBingoResult = {}
    ---comment
    ---@param groupName string
    ---@param taskingType string
    ---@param offset number
    ---@return boolean
    function Spearhead.internal.Air.IsBingoFuel(groupName, taskingType, offset)
        if checkBingoTime[groupName] == nil or checkBingoTime[groupName] < timer.getTime() - 10 then
            local group = Group.getByName(groupName)
            local typeName = nil
            local unit = group:getUnit(1)
            if unit then
                typeName = unit:getTypeName()
            end
            local bingoConfig = GetBingoSetting(groupName, typeName, taskingType)
            if offset == nil then offset = 0 end
            local bingoSetting = bingoConfig["fuel"] or 0.2
            bingoSetting = bingoSetting + offset

            for _, unit in pairs(group:getUnits()) do
                if unit and unit:isExist() == true and unit:inAir() == true and unit:getFuel() < bingoSetting then
                    lastBingoResult[groupName] = true
                    logger:info(groupName .. "Is Bingo Fuel")
                    return true
                end
            end
        end
        return lastBingoResult[groupName] or false
    end

    local checkWeaponTime = {}
    local lastWeaponResult = {}
    ---comment
    ---@param groupName string
    ---@param taskingType string
    ---@return boolean
    function Spearhead.internal.Air.IsBingoWeapons(groupName, taskingType)
        if checkWeaponTime[groupName] == nil or checkWeaponTime[groupName] < timer.getTime() - 10 then
            checkWeaponTime[groupName] = timer.getTime()

            local group = Group.getByName(groupName)
            local typeName = nil
            local unit = group:getUnit(1)
            if unit then
                typeName = unit:getTypeName()
            end
            local bingoConfig = GetBingoSetting(groupName, typeName, taskingType)

            for _, unit in pairs(group:getUnits()) do

                local ammo = unit:getAmmo()

                for _, weapon in pairs(ammo) do
                    local count = weapon["count"] or 0
                    if count <= 0 then
                        if weapon["category"] == 0 then
                            -- guns
                            if bingoConfig["nobullets"] == true then return true end
                        elseif weapon["category"] == 1 then
                            -- missiles
                            if weapon["missileCategory"] == 2 then
                                -- AA Missiles
                                if weapon["guidance"] == 2 then
                                    --IR
                                    if bingoConfig["noheatseekingmissiles"] == true then 
                                        logger:info(groupName .. "Is Bingo Weapons")
                                        return true
                                    end
                                elseif weapon["guidance"] == 3 or weapon["guidance"] == 4 then
                                    --Active and Semi-Active radar missiles
                                    if bingoConfig["noradarmissiles"] == true then 
                                        logger:info(groupName .. "Is Bingo Weapons")
                                        return true 
                                    end
                                end
                            end
                        elseif weapon["category"] == 2 then
                            -- rockets
                            --[[
                                TODO: Add Bingo settings for AG missions
                            ]]
                        elseif weapon["category"] == 3 then
                            -- bombs
                            
                        end
                    end 
                end
            end
            return false
        end

        return lastWeaponResult[groupName] or false
    end
end
