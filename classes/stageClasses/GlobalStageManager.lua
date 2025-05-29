

local StagesByName = {}

---@type table<string, Array<Stage>>
local StagesByIndex = {}

---@type table<string, Array<Stage>>
local SideStageByIndex = {}

---@type table<string, Array<WaitingStage>>
local WaitingStagesByIndex = {}

local currentStage = -99


GlobalStageManager = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logLevel LogLevel
---@return nil
function GlobalStageManager:NewAndStart(database, stageConfig, logLevel)
    local logger = Spearhead.LoggerTemplate.new("StageManager", logLevel)
    logger:info("Using Stage Log Level: " .. logLevel)
    local o = {}
    setmetatable(o, { __index = self })

    o.logger = logger
    if stageConfig.isAutoStages ~= true then
        logger:warn("Spearhead will not automatically progress stages due to the given settings. If you manually have implemented this, please ignore this message")
    end

    ---@type OnStageChangedListener
    local OnStageNumberChangedListener = {
        OnStageNumberChanged = function (self, number)
            currentStage = number
        end
    }

    Spearhead.Events.AddStageNumberChangedListener(OnStageNumberChangedListener)

    ---@type StageCompleteListener
    local OnStageCompleteListener = {
        OnStageComplete = function(self, stage)
            logger:debug("Receiving stage complete event from: " .. stage.zoneName)

            local anyIncomplete = false
            logger:debug("Checking stages for index: " .. tostring(currentStage))
            for index, stage in pairs(StagesByIndex[tostring(currentStage)]) do
                if stage:IsComplete() == false then
                    anyIncomplete = true
                    logger:debug("Need to wait for Stage " .. stage.zoneName .. " to be completed")
                else
                    logger:debug("Stage verified to be completed:  " .. stage.zoneName)
                end
            end

            if anyIncomplete == false and stageConfig.isAutoStages == true then

                -- CHECK WAITING STAGES 
                local nextStage = currentStage + 1
                
                if WaitingStagesByIndex[tostring(nextStage)] then
                    for _, waitingStage in pairs(WaitingStagesByIndex[tostring(nextStage)]) do
                        if waitingStage:IsActive() == false then
                            waitingStage:ActivateStage()
                        end
                    end
                end
                
                local anyWaiting = false
                if WaitingStagesByIndex[tostring(nextStage)] then
                    for _, waitingStage in pairs(WaitingStagesByIndex[tostring(nextStage)]) do
                        if waitingStage:IsComplete() == false then
                            anyWaiting = true
                        end
                    end
                end

                if anyWaiting == false then
                    logger:debug("Setting next stage to: " .. tostring(currentStage + 1))
                    Spearhead.Events.PublishStageNumberChanged(currentStage + 1)
                end
            end
        end
    }

    
    for _, stageName in pairs(database:getStagezoneNames()) do
        logger:debug("Found stage zone with name: " .. stageName)

        if Spearhead.Util.startswith(stageName, "missionstage", true) then
            local valid = true
            local split = Spearhead.Util.split_string(stageName, "_")
            if Spearhead.Util.tableLength(split) < 2 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if Spearhead.Util.tableLength(split) < 3 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a stage name")
            end

            local orderNumber = nil 
            local isSideStage = false
            if valid == true then
                local orderNumberString = string.lower(split[2])
                if Spearhead.Util.startswith(orderNumberString, "x") == true then
                    isSideStage = true

                    orderNumberString = string.gsub(orderNumberString, "x", "")
                    orderNumber = tonumber(orderNumberString)
                else
                    orderNumber = tonumber(split[2])
                end

                if orderNumber == nil then
                    Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a valid order number : " .. split[2])
                    valid = false
                end
            end
                
            local stageDisplayName = split[3]
            local stagelogger = Spearhead.LoggerTemplate.new(stageName, logLevel)
            if valid == true and orderNumber then

                ---@type StageInitData
                local initData = {
                    stageDisplayName = stageDisplayName,
                    stageNumber =  orderNumber,
                    stageZoneName = stageName,
                }

                if isSideStage == true then
                    local stage = Spearhead.classes.stageClasses.Stages.ExtraStage.New(database, stageConfig, stagelogger, initData)
                    stage:AddStageCompleteListener(OnStageCompleteListener)

                    if SideStageByIndex[tostring(orderNumber)] == nil then SideStageByIndex[tostring(orderNumber)] = {} end
                    table.insert(SideStageByIndex[tostring(orderNumber)], stage) 
                else 
                    local stage = Spearhead.classes.stageClasses.Stages.PrimaryStage.New(database, stageConfig, stagelogger, initData)
                    stage:AddStageCompleteListener(OnStageCompleteListener)
                    
                    if StagesByIndex[tostring(orderNumber)] == nil then StagesByIndex[tostring(orderNumber)] = {} end
                    table.insert(StagesByIndex[tostring(orderNumber)], stage) 
                end 
            end
        end

        if Spearhead.Util.startswith(stageName, "waitingstage", true) then
            local valid = true

            local split = Spearhead.Util.split_string(stageName, "_")

            if Spearhead.Util.tableLength(split) < 3 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if valid == true then
                local stageIndexString = split[2]
                local stageIndex = tonumber(stageIndexString)

                if not stageIndex then
                    Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a valid order number")
                    valid = false
                end

                local waitingSecondsString = split[3]
                local waitingSeconds = tonumber(waitingSecondsString)
                if not waitingSeconds then
                    Spearhead.AddMissionEditorWarning("Waiting Stage zone with name " .. stageName .. " does not have a valid amount of seconds parameter")
                    valid = false
                end

                if valid == true then 
                    local stagelogger = Spearhead.LoggerTemplate.new(stageName, logLevel)

                    ---@type WaitingStageInitData
                    local initData = {
                        stageDisplayName = "Waiting Stage " .. stageIndex,
                        stageNumber =  stageIndex or -99,
                        stageZoneName = stageName,
                        waitingSeconds = waitingSeconds --[[@as integer]]
                    }
                    local waitingStage = Spearhead.classes.stageClasses.Stages.WaitingStage.New(database, stageConfig, stagelogger, initData)

                    if WaitingStagesByIndex[tostring(stageIndex)] == nil then
                        WaitingStagesByIndex[tostring(stageIndex)] = {}
                    end
                    table.insert(WaitingStagesByIndex[tostring(stageIndex)], waitingStage)

                    waitingStage:AddStageCompleteListener(OnStageCompleteListener)
                end
            end
        end
    end



    return o
end


GlobalStageManager.printFullOverview = function ()
    
    local logger = Spearhead.LoggerTemplate.new("StageOverview", "INFO")
    logger:info("Stage overview:")

    local max = 0 
    local lines = {}
    for stageIndex, stages  in pairs(StagesByIndex) do
        
        local totalStrike = 0
        local totalbai = 0
        local totaldead = 0
        local totalMissions = 0
        local totalCas = 0

        for _, stage in pairs(stages) do
            
            local strike, dead, bai, cas = stage:GetStageStats()

            totalStrike = totalStrike + strike
            totalbai = totalbai + bai
            totaldead = totaldead + dead
            totalCas = totalCas + cas
            totalMissions = totalMissions + strike + dead + bai + cas
        end

        local index = tonumber(stageIndex)
        if index then
            if index > max then
                max = index
            end
            lines[index] ="Stage# " .. tostring(stageIndex).. " | " .. totalStrike .. " strikes |  " .. totaldead .. " dead | " .. totalbai .. " BAI | " .. totalCas .. " CAS | Total:" .. totalMissions
        else
            logger:warn("Stage index is not a number: " .. stageIndex)
        end
    end

    for i = 1, max do
        if lines[i] then
            logger:info(lines[i])
        end
    end

end

---comment
---@param stageNumber number
---@return boolean | nil
GlobalStageManager.isStageComplete = function (stageNumber)

    local stageIndex = tostring(stageNumber)

    if StagesByIndex[stageIndex] == nil then return nil end
    
    for _, stage in ipairs(StagesByIndex[stageIndex]) do
        if stage:IsComplete() == false then
            return false
        end
    end

    return true
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalStageManager = GlobalStageManager
