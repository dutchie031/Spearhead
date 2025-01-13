
local Persistence = {}
do
    --[[
        The Tables: 

        tables {
            number activeStage;

            Dict stages: [
                "stageName": {
                    Dict missions: [
                        "missionName":{
                            boolean isCompleted;
                            Dict aliveUnits: [
                                "unitName" : true | false
                            ]
                        }
                    ]
                }
            ]
        }
    ]]--

    local persistanceWriteIntervalSeconds = 15
    local enabled = false

    local tables = {}
    tables.activeStage = nil
    tables.stages = {}
    tables.dead_units = {}


    local logger = {}

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.Persistence == nil then SpearheadConfig.Persistence = {} end

    local path  = (SpearheadConfig.Persistence.directory or (lfs.writedir() .. "\\Data" )) .. "\\" .. (SpearheadConfig.Persistence.fileName or "Spearhead_Persistence.json")
    local updateRequired = false

    local createFileIfNotExists = function()
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
        logger:info("Loading data from persistance file...")
        local f  = io.open(path, "r")
        if f == nil then
            return
        end

        local json = f:read("*a")
        local lua = net.json2lua(json)

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
                        country_id = deadState.country_id,
                        isCleaned = deadState.isCleaned
                    }
                end
            end
        end

        f:close()
    end

    local writeToFile = function()
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

    Persistence.Init = function(persistenceLogger)
        logger = persistenceLogger

        logger:info("Initiating Persistance Manager")

        if lfs == nil or io == nil then
            env.error("[Spearhead][Persistence] lfs and io seem to be sanitized. Persistence is skipped and disabled")
            return
        end

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

    ---Get the active stage as in the persistance file
    ---@return number|nil
    Persistence.GetActiveStage = function()
        if tables.activeStage then
            return tables.activeStage
        end
        return nil
    end

    ---Checks if the mission is complete
    ---@param stageName any
    ---@param missionZoneName any
    ---@return boolean
    Persistence.IsMissionComplete = function(stageName, missionZoneName)

        if tables.stages[stageName] and tables.stages[stageName].missions and tables.stages[stageName].missions[missionZoneName] then
            return tables.stages[stageName].missions[missionZoneName].isComplete == true
        end
        
        return false
    end

    ---Check if the unit was dead during the last save. Nil if alive
    ---@param unitName string name
    ---@return table|nil { isDead, pos = {x,y,z}, heading, type, country_id }
    Persistence.UnitDeadState = function(unitName)
        return tables.dead_units[unitName]
    end

    ---Pass the unit to be saved as "dead"
    ---@param name string
    ---@param position table { x, y ,z } 
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

    Persistence.CorpseCleaned = function(unitName)
        local data = tables.dead_units[unitName]
        if data then
            data.isCleaned = true
        end
        updateRequired = true
    end

end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.persistence == nil then Spearhead.classes.persistence = {} end
Spearhead.classes.persistence.Persistence = Persistence