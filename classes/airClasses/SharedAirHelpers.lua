
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
    REARMING = 7
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
            Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
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
            Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
end

