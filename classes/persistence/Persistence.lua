

local Persistence = {}

do
    local enabled = Spearhead.Persistence ~= nil and SpearheadConfig.Persistence.enabled == true

    if enabled == true and lfs == nil and io == nil then
        env.error("[Spearhead][Persistence] lfs and io seem to be sanitized. Persistence is skipped and disabled")
        enabled = false
    end

    local path = (Spearhead.Persistence.directory or lfs.writedir()) .. "/" .. (Spearhead.Persistence.fileName or "Spearhead_Persistence.json")

    local updateRequired = false

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

    local tables = {}
    tables.activeStage = nil
    tables.stages = {}
    tables.dead_units = {}

    if enabled == true then
        -- load from file during start.

        -- check if file exists.

        local function LoadFromFile()
            local f = io.open(path, "r")
            if f == nil then
                env.warn("No such file found at '" .. path .. "'. Creating it")
                f = io.open(path, "w")
                if f == nil then
                    error("could not create a new file for persistence")
                end
                f:write("{}")
                env.info("New file created at: " .. path)
            end

            local jsonString = f:read("a")
            
            local luaTable = net.json2lua()
            if f ~= nil then
                f:close()
            end

            return luaTable
        end

        local status, result = pcall(LoadFromFile)

        if status == false then
            env.error(("[Spearhead][Persistence] " .. Spearhead.Util.toString(result)))
        else 

            --TODO: Load all. After dumping just to get a better idea of the data structure
            if result ~= nil then

                if result["activeStage"] ~= nil then
                    tables.activeStage = tonumber(result["activeStage"])
                end

                if result["stages"] ~= nil then
                    for stageZoneName, value in ipairs(t) do
                        
                    end
                end
            end
        end
    end

    ---Sets the stage in the persistence table
    ---@param stageNumber number 
    Persistence.SetActiveStage = function(stageNumber)
        tables.activeStage = stageNumber
        updateRequired = true
    end

    Persistence.UpdateMission = function (stageName, missionName, isComplete, unitsDict)

    end

    Persistence.GetMissionStartData = function(stageName, missionName)

    end

    local writeToFile = function()

        local f = io.open()

    end

    local UpdateContinuous = function(null, time)

        if updateRequired then 
            local status, result = pcall(writeToFile)
            if status == false then
                env.error("[Spearhead][Persistence] Could not write state to file: " .. result)
            end
        end

        return time + 120
    end

    if enabled == true then
        timer.scheduleFunction(UpdateContinuous, nil, timer.getTime() + 120)
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.internal == nil then Spearhead.internal = {} end
Spearhead.internal.Persistence = Persistence