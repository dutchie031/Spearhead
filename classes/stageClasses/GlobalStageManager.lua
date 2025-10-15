---@class StageLane
---@field name string
---@field CurrentStageIndex number
---@field StagesByIndex table<string, Array<Stage>>
---@field SideStagesByIndex table<string, Array<Stage>>
---@field WaitingStagesByIndex table<string, Array<WaitingStage>>

local DEFAULT_STAGE_LANE_NAME = "main_default_lane"

---@class GlobalStageManager : OnStageChangedListener, StageCompleteListener
---@field private _database Database
---@field private _stageConfig StageConfig
---@field private _logger Logger
---@field private _spawnManager SpawnManager
---@field private _currentStage number
---@field private _stageLanes table<string, StageLane>
local GlobalStageManager = {}
GlobalStageManager.__index = GlobalStageManager
GlobalStageManager.DEFAULT_STAGE_LANE_NAME = DEFAULT_STAGE_LANE_NAME

GlobalStageManager.Singleton = nil

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger Logger
---@param spawnManager SpawnManager
---@return GlobalStageManager
function GlobalStageManager.NewAndStart(database, stageConfig, logger, spawnManager)
    local self = setmetatable({}, GlobalStageManager)
    if GlobalStageManager.Singleton then
        return GlobalStageManager.Singleton
    end
    GlobalStageManager.Singleton = self

    self._logger = logger

    if stageConfig.isAutoStages ~= true then
        self._logger:warn(
        "Spearhead will not automatically progress stages due to the given settings. If you manually have implemented this, please ignore this message")
    end

    self._database = database
    self._stageConfig = stageConfig
    self._spawnManager = spawnManager

    self._stageLanes = {
        [DEFAULT_STAGE_LANE_NAME] = {
            name = DEFAULT_STAGE_LANE_NAME,
            CurrentStageIndex = -99,
            StagesByIndex = {},
            SideStagesByIndex = {},
            WaitingStagesByIndex = {}
        }
    }

    Spearhead.Events.AddStageNumberChangedListener(self)

    self:InitStages()

    return self
end

---@param number number
---@param stageLane string
function GlobalStageManager:OnStageNumberChanged(number, stageLane)
    
    if stageLane == nil then stageLane = DEFAULT_STAGE_LANE_NAME end
    local lane = self._stageLanes[stageLane]
    if lane then
        lane.CurrentStageIndex = number
    end
    self:CheckAndUpdate()
end

function GlobalStageManager:CheckAndUpdate()

    -- the lowest index number of all lanes that have continuations 
    local lowestIndexWithContinuations = nil

    
    for stageLaneName, stages in pairs(self._stageLanes) do
        local currentStageIndex = stages.CurrentStageIndex
        if stages.StagesByIndex[tostring(currentStageIndex + 1)] then
            lowestIndexWithContinuations = lowestIndexWithContinuations or currentStageIndex
        end
    end

    local defaultLane = self._stageLanes[DEFAULT_STAGE_LANE_NAME]

    for stageLaneName, stageLane in pairs(self._stageLanes) do
        if stageLaneName ~= DEFAULT_STAGE_LANE_NAME then
            local hasNext, currentStageIndex = self:CheckAndUpdateStageLane(stageLane)
            if hasNext == true and (lowestIndexWithContinuations == nil or (currentStageIndex < lowestIndexWithContinuations)) then
                lowestIndexWithContinuations = currentStageIndex
            end
        end
    end

    if defaultLane then
        if lowestIndexWithContinuations == nil or (defaultLane.CurrentStageIndex < lowestIndexWithContinuations) then
            
        else
            self._logger:debug("Skipping default lane check as other lanes have continuations at a lower or same index")
        end
    end
end

---@private
---@param stageLane StageLane
function GlobalStageManager:CheckAndUpdateStageLane(stageLane)

    local anyIncomplete = false
    local hasNext = false

    local currentStages = stageLane.StagesByIndex[tostring(stageLane.CurrentStageIndex)]


    for _, stage in pairs(currentStages) do
        if stage:IsComplete() == false then
            anyIncomplete = true
        end
    end

    --[[
        TODO: Implement waiting stages again
    ]]

    if anyIncomplete == false and self._stageConfig.isAutoStages == true then
        self._logger:debug("All stages complete for lane: " .. stageLane.name .. " index " .. tostring(stageLane.CurrentStageIndex))
        if stageLane.name == DEFAULT_STAGE_LANE_NAME then
            Spearhead.Events.PublishStageNumberChanged(stageLane.CurrentStageIndex + 1, nil)
        else
            Spearhead.Events.PublishStageNumberChanged(stageLane.CurrentStageIndex + 1, stageLane.name)
        end
    end

    if stageLane.StagesByIndex[tostring(stageLane.CurrentStageIndex + 1)] then
        hasNext = true
    end

    return hasNext, stageLane.CurrentStageIndex

end

---@param stage Stage
function GlobalStageManager:OnStageComplete(stage)
    self._logger:debug("Receiving stage complete event from: " .. stage.zoneName)

    self:CheckAndUpdate()

    local anyIncomplete = false
    self._logger:debug("Checking stages for index: " .. tostring(self._currentStage))
    for index, stage in pairs(StagesByIndex[tostring(currentStage)]) do
        if stage:IsComplete() == false then
            anyIncomplete = true
            self._logger:debug("Need to wait for Stage " .. stage.zoneName .. " to be completed")
        else
            self._logger:debug("Stage verified to be completed:  " .. stage.zoneName)
        end
    end

    if anyIncomplete == false and self._stageConfig.isAutoStages == true then
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

---@private
function GlobalStageManager:InitStages()
    for _, stageName in pairs(self._database:getStagezoneNames()) do
        self._logger:debug("Found stage zone with name: " .. stageName)

        if Spearhead.Util.startswith(stageName, "missionstage", true) then
            local valid = true
            local split = Spearhead.Util.split_string(stageName, "_")
            if Spearhead.Util.tableLength(split) < 2 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " ..
                stageName .. " does not have a order number or valid format")
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
                    Spearhead.AddMissionEditorWarning("Stage zone with name " ..
                    stageName .. " does not have a valid order number : " .. split[2])
                    valid = false
                end
            end

            local stageDisplayName = split[3]
            local stagelogger = Spearhead.LoggerTemplate.new(stageName, self._logger.LogLevel)
            if valid == true and orderNumber then
                ---@type StageInitData
                local initData = {
                    stageDisplayName = stageDisplayName,
                    stageNumber = orderNumber,
                    stageZoneName = stageName,
                }

                if isSideStage == true then
                    local stage = Spearhead.classes.stageClasses.Stages.ExtraStage.New(self._database, self._stageConfig, stagelogger,
                        initData, self._spawnManager)
                    stage:AddStageCompleteListener(self)

                    local stageLaneName = stage:GetLaneName() or DEFAULT_STAGE_LANE_NAME
                    
                    
                    if SideStageByIndex[tostring(orderNumber)] == nil then SideStageByIndex[tostring(orderNumber)] = {} end
                    table.insert(SideStageByIndex[tostring(orderNumber)], stage)
                else
                    local stage = Spearhead.classes.stageClasses.Stages.PrimaryStage.New(database, stageConfig,
                        stagelogger, initData, spawnManager)
                    stage:AddStageCompleteListener(self)

                    if StagesByIndex[tostring(orderNumber)] == nil then StagesByIndex[tostring(orderNumber)] = {} end
                    table.insert(StagesByIndex[tostring(orderNumber)], stage)
                end
            end
        end

        if Spearhead.Util.startswith(stageName, "waitingstage", true) then
            local valid = true

            local split = Spearhead.Util.split_string(stageName, "_")

            if Spearhead.Util.tableLength(split) < 3 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " ..
                stageName .. " does not have a order number or valid format")
                valid = false
            end

            if valid == true then
                local stageIndexString = split[2]
                local stageIndex = tonumber(stageIndexString)

                if not stageIndex then
                    Spearhead.AddMissionEditorWarning("Stage zone with name " ..
                    stageName .. " does not have a valid order number")
                    valid = false
                end

                local waitingSecondsString = split[3]
                local waitingSeconds = tonumber(waitingSecondsString)
                if not waitingSeconds then
                    Spearhead.AddMissionEditorWarning("Waiting Stage zone with name " ..
                    stageName .. " does not have a valid amount of seconds parameter")
                    valid = false
                end

                if valid == true then
                    local stagelogger = Spearhead.LoggerTemplate.new(stageName, logLevel)

                    ---@type WaitingStageInitData
                    local initData = {
                        stageDisplayName = "Waiting Stage " .. stageIndex,
                        stageNumber = stageIndex or -99,
                        stageZoneName = stageName,
                        waitingSeconds = waitingSeconds --[[@as integer]]
                    }
                    local waitingStage = Spearhead.classes.stageClasses.Stages.WaitingStage.New(database, stageConfig,
                        stagelogger, initData, spawnManager)

                    if WaitingStagesByIndex[tostring(stageIndex)] == nil then
                        WaitingStagesByIndex[tostring(stageIndex)] = {}
                    end
                    table.insert(WaitingStagesByIndex[tostring(stageIndex)], waitingStage)

                    waitingStage:AddStageCompleteListener(OnStageCompleteListener)
                end
            end
        end
    end
end

---@private
function GlobalStageManager:GetOrCreateStageLane(laneName)

    local stagelane = self._stageLanes[laneName]

    if not stagelane then
        stagelane = {
            name = laneName,
            CurrentStageIndex = -99,
            StagesByIndex = {},
            SideStagesByIndex = {},
            WaitingStagesByIndex = {}
        }
        
        self._stageLanes[laneName] = stagelane
    end
    return stagelane
end

function GlobalStageManager:printFullOverview()
    local logger = Spearhead.LoggerTemplate.new("StageOverview", "INFO")
    logger:info("Stage overview:")

    local max = 0
    local lines = {}
    for stageIndex, stages in pairs(StagesByIndex) do
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
            lines[index] = "Stage# " ..
            tostring(stageIndex) ..
            " | " ..
            totalStrike ..
            " strikes |  " ..
            totaldead .. " dead | " .. totalbai .. " BAI | " .. totalCas .. " CAS | Total:" .. totalMissions
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
---@param stageLane string?
---@return boolean | nil
GlobalStageManager.isStageComplete = function(stageNumber, stageLane)

    if not stageLane then stageLane = DEFAULT_STAGE_LANE_NAME end

    local self = GlobalStageManager.Singleton

    local lane = self:GetOrCreateStageLane(stageLane)
    local stages = lane.StagesByIndex[tostring(stageNumber)]
    for _, stage in pairs(stages) do
        if stage:IsComplete() == false then
            return false
        end
    end
    return true
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
Spearhead.classes.stageClasses.GlobalStageManager = GlobalStageManager
