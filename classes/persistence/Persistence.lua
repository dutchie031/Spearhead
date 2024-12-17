

local Persistence = {}

do
    local enabled = Spearhead.Persistence ~= nil and SpearheadConfig.Persistence.enabled == true

    if enabled == true and lfs == nil and io == nil then
        env.error("[Spearhead][Persistence] lfs and io seem to be sanitized. Persistence is skipped and disabled")
        enabled = false
    end

    local path = (Spearhead.Persistence.directory or lfs.writedir()) .. "/" .. (Spearhead.Persistence.fileName or "Spearhead_Persistence.json")

    local updateRequired = false

    local tables = {}
    tables.activeStage = nil

    tables.stages = {}
    
    tables.dead_units = {}

    if enabled == true then
        -- load from file during start.

        -- check if file exists.

        local f = io.open(path, "r")
        if f == nil then
            env.warn("No such file found at '" .. path .. "'. Creating it")
            f = io.open(path, "w")
            env.info("New file created at: " .. path)
        end


        f:close()
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

    local UpdateContinuous = function(null, time)

        

        return time + 120
    end

    if enabled == true then
        timer.scheduleFunction(UpdateContinuous, nil, timer.getTime() + 120)
    end
end


if Spearhead == nil then Spearhead = {} end
if Spearhead.internal == nil then Spearhead.internal = {} end
Spearhead.internal.Persistence = Persistence