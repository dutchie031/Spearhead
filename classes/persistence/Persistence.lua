
local Persistence = {}
do
    ---@class PersistentData
    ---@field dead_units table<string, DeathState>
    ---@field random_missions table<string, MissionState>
    ---@field activeStage integer|nil

    ---@class DeathState 
    ---@field isDead boolean
    ---@field pos Position
    ---@field heading number
    ---@field type string
    ---@field country_id integer


    local persistanceWriteIntervalSeconds = 15
    local enabled = false

    ---@type PersistentData
    local tables = {
        dead_units = {},
        random_missions = {},
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

        if lua.dead_units then
            logger:debug("Found saved dead units")
            for name, deadState in pairs(lua.dead_units) do
                logger:debug("Found saved dead unit: " .. name)

                if type(deadState) == "table" then
                    tables.dead_units[name] = {
                        isDead = deadState.isDead == true,
                        pos = deadState.pos,
                        heading = deadState.heading,
                        type = deadState.type,
                        country_id = deadState.country_id
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


    ---comment
    ---@param persistenceLogger Logger
    Persistence.Init = function(persistenceLogger)
        logger = persistenceLogger

        logger:info("Initiating Persistence Manager")

        if lfs == nil or io == nil then
            logger:error("lfs and io seem to be sanitized. Persistence is skipped and disabled")
            return
        end

        path = (SpearheadConfig.Persistence.directory or (lfs.writedir() .. "\\Data" )) .. "\\" .. (SpearheadConfig.Persistence.fileName or "Spearhead_Persistence.json")

        logger:info("Persistence file path: " .. path)

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

    ---Check if the unit was dead during the last save. Nil if persitance not enabled
    ---@param unitName string name
    ---@return DeathState|nil { isDead, pos = {x,y,z}, heading, type, country_id } 
    Persistence.UnitDeadState = function(unitName)
        if Persistence.isEnabled() == false then
            return nil
        end

        local entry =  tables.dead_units[unitName]
        if entry then
            return entry
        else
            return { isDead = false }
        end
    end

    ---Pass the unit to be saved as "dead"
    ---@param name string
    ---@param position Position { x, y ,z } 
    ---@param heading number
    ---@param type string 
    ---@param country_id number
    Persistence.UnitKilled = function (name, position, heading, type, country_id)
        if enabled == false then return end

        tables.dead_units[name] = { 
            isDead = true, 
            pos = position, 
            heading = heading, 
            type = type, 
            country_id = country_id,
            isCleaned = false
         }
        updateRequired = true
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.persistence == nil then Spearhead.classes.persistence = {} end
Spearhead.classes.persistence.Persistence = Persistence