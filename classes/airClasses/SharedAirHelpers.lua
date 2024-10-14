if not Spearhead.internal then Spearhead.internal = {} end

if Spearhead.internal.Air == nil then Spearhead.internal.Air = {} end

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

do --routes
    if Spearhead.internal.Air.Routing == nil then Spearhead.internal.Air.Routing = {} end

    Spearhead.internal.Air.Routing.GetOrCreateCapRoute = function (database, stageNumber, stageName, baseId)
        
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
                        return { [1] =  closest, [2] = { x = stagezone.x, z = stagezone.z } }
                    else
                        return { [1] = { x = stagezone.x, z = stagezone.z }, [2] = closest }
                    end
                end
            end
            return nil
        end
    end

    Spearhead.internal.Air.Routing.GetOrCreateCasRoute = function (database, stageNumber, stageName, baseId)



    end

end

do -- bingo settings

    local function GetBaseProfileSettings()

        local ww2 = {
            CAP = {
                NoRadarMissiles = false,
                NoHeatSeekingMissiles = false,
                NoBullets = true
            },
            ESCORT = {
                NoRadarMissiles = false,
                NoHeatSeekingMissiles = false,
                NoBullets = true
            }
        }

        local modern = {
            CAP = {
                NoRadarMissiles = false,
                NoHeatSeekingMissiles = true,
                NoBullets = true
            },
            ESCORT = {
                NoRadarMissiles = false,
                NoHeatSeekingMissiles = true,
                NoBullets = true
            }
        }

        local profile = SpearheadConfig.BingoSettings.baseProfile or "modern"

        if profile == "ww2" then
            return ww2
        end

        return modern


    end


    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.BingoSettings == nil then SpearheadConfig.BingoSettings = {} end
    local BingoSettings = {



    }

    local checkBingoTime = {}
    local lastBingoResult = {}
    function Spearhead.internal.Air.IsBingoFuel(groupName, offset)

        if checkBingoTime[groupName] == nil or checkBingoTime[groupName] < timer.getTime() - 10 then
            if offset == nil then offset = 0 end
            local bingoSetting = 0.20
            bingoSetting = bingoSetting + offset

            local group = Group.getByName(groupName)
            for _, unit in pairs(group:getUnits()) do
                if unit and unit:isExist() == true and unit:inAir() == true and unit:getFuel() < bingoSetting then
                    lastBingoResult[groupName] = true
                    return true
                end
            end
        end
        
        return lastBingoResult[groupName] or false
    end

    local checkWeaponTime = {}
    local lastWeaponResult = {}
    function Spearhead.internal.Air.IsBingoWeapons(groupName, type)
        if checkWeaponTime[groupName] == nil or checkWeaponTime[groupName] < timer.getTime() - 10 then
            checkWeaponTime[groupName] = timer.getTime()

            if type == "CAP" then
                

                
            end

            if type == "ESCORT" then
                
            end

            if type == "CAS" then
                
            end
        end
        
        return lastWeaponResult[groupName] or false
    end

end