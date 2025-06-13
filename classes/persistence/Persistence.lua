
---@class Perstistence
local Persistence = {}
do
    local EXTENSION = "spearhead"

    ---@class PersistentData
    ---@field unitsStates table<string, UnitState>
    ---@field random_missions table<string, MissionState>
    ---@field deliveredKilos table<string, number>
    ---@field activeStage integer|nil

    ---@class UnitState 
    ---@field isDead boolean
    ---@field pos Vec3?
    ---@field heading number?
    ---@field type string?


    local persistanceWriteIntervalSeconds = 15
    local enabled = false

    ---@type PersistentData
    local tables = {
        unitsStates = {},
        random_missions = {},
        deliveredKilos = {},
        activeStage = nil
    }

    local logger = {}

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.Persistence == nil then SpearheadConfig.Persistence = {} end

    local path  = nil
    local updateRequired = false

    local createFileIfNotExists = function()
        if not path then return end

        local f = io.open(path, "r")
        if f == nil then
            f = io.open(path, "w+")
            if f == nil then
                logger:error("Could not create a file")
            else
                f:write("{}")
                f:close()
            end
        else
            f:close()
        end
    end

    local loadTablesFromFile = function()
        if not path then return end

        logger:info("Loading data from persistance file...")
        local f  = io.open(path, "r")
        if f == nil then
            return
        end

        local json = f:read("*a")
        f:close()

        local lua = net.json2lua(json) --[[@as PersistentData]]

        if lua.activeStage then
            logger:info("Found active stage from save: " .. lua.activeStage)
            tables.activeStage = lua.activeStage
        end

        if lua.unitsStates then
            logger:debug("Found saved dead units")
            for name, deadState in pairs(lua.unitsStates) do
                logger:debug("Found saved dead unit: " .. name)

                if type(deadState) == "table" then
                    tables.unitsStates[name] = {
                        isDead = deadState.isDead == true,
                        pos = deadState.pos,
                        heading = deadState.heading,
                        type = deadState.type
                    }
                end
            end
        end

        
    end

    local writeToFile = function()
        if not path then return end

        local f = io.open(path, "w+")
        if f == nil then
            error("Could not open file for writing")
            return
        end

        local jsonString = net.lua2json(tables)
        f:write(jsonString)

        if f ~= nil then
            f:close()
        end
    end

    local UpdateContinuous = function(null, time)

        if updateRequired then 
            local status, result = pcall(writeToFile)
            if status == false then
                env.error("[Spearhead][Persistence] Could not write state to file: " .. result)
            end
        end

        return time + persistanceWriteIntervalSeconds
    end

    Persistence.UpdateNow = function()
        if enabled == true then
            writeToFile()
        end
    end

    Persistence.isEnabled = function()
        return enabled
    end


    local warnForNonPersistenceContinous = function(null, time)
        trigger.action.outText("Persistence was enabeld, however, io and lfs are not available and no persistence will be done. Make sure to either disable persistence or fix the issues before continuing.", 10)
        return time + 9
    end

    ---@param dir string @BaseDirectory
    ---@return string
    local getLastFileOrDefault = function(dir, startsWith, default)
        local latestFile, lastNumber = default, 0
        for file in lfs.dir(dir) do
            local split = Spearhead.Util.split_string(file, ".")
            local doesStartWith = Spearhead.Util.startswith(file, startsWith, true)
            if split and #split > 0 and split[#split] == EXTENSION and doesStartWith == true then
                local fullPath = dir .. "/" .. file
                local numberString = split[#split-1]
                local number = tonumber(numberString)
                if number ~= nil and number > lastNumber then
                    lastNumber = number
                    latestFile = fullPath
                end
            end
        end
        return latestFile
    end

    ---comment
    ---@param persistenceLogger Logger
    Persistence.Init = function(persistenceLogger)
        logger = persistenceLogger

        logger:info("Initiating Persistence Manager")

        if lfs == nil or io == nil then
            logger:error("lfs and io seem to be sanitized. Persistence is skipped and disabled")
            enabled = false
            timer.scheduleFunction(warnForNonPersistenceContinous, nil, timer.getTime() + 10)
            return
        end

        ---@type string
        local dir = lfs.writedir() .. "\\Data"
        local fileName = "Spearhead_Persistence.0.spearhead"
        if SpearheadConfig and SpearheadConfig.Persistence then
            if SpearheadConfig.Persistence.fileName then

                local userFileName = SpearheadConfig.Persistence.fileName
                local split = Spearhead.Util.split_string(userFileName, ".")

                if not split and #split < 3 then
                    split[#split+1] = "0"
                    split[#split+1] = "spearhead"
                end

                if tonumber(split[#split-1]) == nil then
                    split[#split+1] = "0"
                    split[#split+1] = "spearhead"
                end
                
                fileName = table.concat(split, ".")
            end

            if SpearheadConfig.Persistence.directory ~= nil then
                dir = SpearheadConfig.Persistence.directory
            end
        end

        local split = Spearhead.Util.split_string(fileName, ".")
        local matchingPart = table.concat(Spearhead.Util.sublist(split, 1, #split-2), ".")

        local lastFile = getLastFileOrDefault(dir--[[@as string]], matchingPart, fileName)

        local fileSplit = Spearhead.Util.split_string(lastFile, ".")
        fileSplit[#fileSplit-1] = tostring(tonumber(fileSplit[#fileSplit-1]) + 1)
        fileName = table.concat(fileSplit, ".")

        if lastFile ~= fileName then
            logger:info("Found last persistence file: " .. lastFile)
        else
            logger:info("No previous persistence file found, using default: " .. fileName)
        end

        logger:info("New Persistence file path: " .. path)
        path = dir .. "\\" .. fileName

        createFileIfNotExists()
        loadTablesFromFile()
        timer.scheduleFunction(UpdateContinuous, nil, timer.getTime() + 120)
        enabled = true
    end

    ---Sets the stage in the persistence table
    ---@param stageNumber number 
    Persistence.SetActiveStage = function(stageNumber)
        tables.activeStage = stageNumber
        updateRequired = true
    end

    ---comment
    ---@param missionName string
    ---@param pickedZone string
    Persistence.RegisterPickedRandomMission = function(missionName, pickedZone)
        if enabled == false then return end

        if tables.random_missions == nil then tables.random_missions = {} end
        tables.random_missions[string.lower(missionName)] = pickedZone
        updateRequired = true
    end

    ---Get the picked random mission from the persistence file
    ---@param missionName string
    ---@return string?
    Persistence.GetPickedRandomMission = function(missionName)
        if enabled == false then return nil end
        return tables.random_missions[string.lower(missionName)]
    end

    ---Get the active stage as in the persistance file
    ---@return integer|nil
    Persistence.GetActiveStage = function()
        if tables.activeStage then
            return tables.activeStage
        end
        return nil
    end

    ---comment
    ---@param zoneName string
    ---@param kilos number
    Persistence.SetZoneDeliveredKilos = function(zoneName, kilos)
        if enabled == false then return end

        if tables.deliveredKilos == nil then
            tables.deliveredKilos = {}
        end

        tables.deliveredKilos[zoneName] = kilos
        updateRequired = true
    end

    Persistence.GetZoneDeliveredKilos = function(zoneName)
        if enabled == false then return 0 end

        if tables.deliveredKilos == nil then
            tables.deliveredKilos = {}
        end

        return tables.deliveredKilos[zoneName] or 0
    end



    ---Check if the unit was dead during the last save. Nil if persitance not enabled or no state is found
    ---@param unitName string name
    ---@return UnitState|nil { isDead, pos = {x,y,z}, heading, type, country_id } 
    Persistence.UnitState = function(unitName)
        if Persistence.isEnabled() == false then
            return nil
        end

        local entry =  tables.unitsStates[unitName]
        if entry then
            return entry
        else
            ---@type UnitState
            local state = {
                isDead = false
            }
            return state
        end
    end

    ---Pass the unit to be saved as "dead"
    ---@param name string
    ---@param position Vec3 { x, y ,z } 
    ---@param heading number
    ---@param type string 
    Persistence.UnitKilled = function (name, position, heading, type)
        if enabled == false then return end

        tables.unitsStates[name] = {
            isDead = true,
            pos = position,
            heading = heading,
            type = type,
            isCleaned = false
         }
        updateRequired = true
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.persistence == nil then Spearhead.classes.persistence = {} end
Spearhead.classes.persistence.Persistence = Persistence