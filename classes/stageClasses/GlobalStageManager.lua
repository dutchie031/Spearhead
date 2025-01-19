

local StagesByName = {}

---@type table<string, Array<Stage>>
local StagesByIndex = {}

---@type table<string, Array<Stage>>
local SideStageByIndex = {}

local currentStage = -99


GlobalStageManager = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@return nil
function GlobalStageManager:NewAndStart(database, stageConfig)
    local logger = Spearhead.LoggerTemplate:new("StageManager", stageConfig.logLevel)
    logger:info("Using Stage Log Level: " .. stageConfig.logLevel)
    local o = {}
    setmetatable(o, { __index = self })

    o.logger = logger


    if stageConfig.isAutoStages == false then
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
                end
            end

            if anyIncomplete == false and stageConfig.isAutoStages == true then
                logger:debug("Setting next stage to: " .. tostring(currentStage + 1))
                Spearhead.Events.PublishStageNumberChanged(currentStage + 1)
            end
        end
    }



    for _, stageName in pairs(database:getStagezoneNames()) do
        local valid = true

        local split = Spearhead.Util.split_string(stageName, "_")
        if Spearhead.Util.tableLength(split) < 2 then
            Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a order number or valid format")
            valid = false
        end

        if Spearhead.Util.tableLength(split) < 3 then
            Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a stage name")
            valid = false
        end

        local orderNumber = nil 
        local isSideStage = false
        if valid == true then
            local orderNumberString = string.lower(split[2])
            if Spearhead.Util.startswith(orderNumberString, "x") == true then
                isSideStage = true

                local orderNumberString = string.gsub(orderNumberString, "x", "")
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
        local stagelogger = Spearhead.LoggerTemplate:new(stageName, stageConfig.logLevel)
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
                
                if SideStageByIndex[tostring(orderNumber)] == nil then SideStageByIndex[tostring(orderNumber)] = {} end
                table.insert(SideStageByIndex[tostring(orderNumber)], stage) 
            end 
        end
    end

    return o
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
