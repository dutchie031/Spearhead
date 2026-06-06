local Events = require("classes.spearhead_events")
local Util = require("classes.util.Util")
local Logger = require("classes.util.Logger")
local MissionEditorWarnings = require("classes.util.MissionEditorWarnings")

local ExtraStage = require("classes.stageClasses.Stages.ExtraStage")
local PrimaryStage = require("classes.stageClasses.Stages.PrimaryStage")
local WaitingStage = require("classes.stageClasses.Stages.WaitingStage")

local StagesByName = {}

---@type table<string, Array<Stage>>
local StagesByIndex = {}

---@type table<string, Array<Stage>>
local SideStageByIndex = {}

---@type table<string, Array<WaitingStage>>
local WaitingStagesByIndex = {}

local currentStage = -99

---@class GlobalStageManager : StageCompleteListener
---@field private database Database
---@field private logger Logger
---@field private stageConfig StageConfig
local GlobalStageManager = {}
GlobalStageManager.__index = GlobalStageManager

GlobalStageManager.getCurrentStage = function() return currentStage end

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logLevel LogLevel
---@param spawnManager SpawnManager
---@return nil
function GlobalStageManager.NewAndStart(database, stageConfig, logLevel, spawnManager)
    local logger = Logger.new("StageManager", logLevel)
    logger:info("Using Stage Log Level: " .. logLevel)
    local self = setmetatable({}, GlobalStageManager)
    self.database = database
    self.stageConfig = stageConfig

    self.logger = logger
    if stageConfig.isAutoStages ~= true then
        logger:warn("Spearhead will not automatically progress stages due to the given settings. If you manually have implemented this, please ignore this message")
    end

    ---@type OnStageChangedListener
    local OnStageNumberChangedListener = {
        OnStageNumberChanged = function (self, number)
            currentStage = number
        end
    }


    Events.AddStageNumberChangedListener(OnStageNumberChangedListener)

    for _, stageName in pairs(database:getStagezoneNames()) do
        logger:debug("Found stage zone with name: " .. stageName)

        if Util.startswith(stageName, "missionstage", true) then
            local valid = true
            local split = Util.split_string(stageName, "_")
            if Util.tableLength(split) < 2 then
                MissionEditorWarnings.Add("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if Util.tableLength(split) < 3 then
                MissionEditorWarnings.Add("Stage zone with name " .. stageName .. " does not have a stage name")
            end

            local orderNumber = nil 
            local isSideStage = false
            if valid == true then
                local orderNumberString = string.lower(split[2])
                if Util.startswith(orderNumberString, "x") == true then
                    isSideStage = true

                    orderNumberString = string.gsub(orderNumberString, "x", "")
                    orderNumber = tonumber(orderNumberString)
                else
                    orderNumber = tonumber(split[2])
                end

                if orderNumber == nil then
                    MissionEditorWarnings.Add("Stage zone with name " .. stageName .. " does not have a valid order number : " .. split[2])
                    valid = false
                end
            end
                
            local stageDisplayName = split[3]
            local stagelogger = Logger.new(stageName, logLevel)
            if valid == true and orderNumber then

                ---@type StageInitData
                local initData = {
                    stageDisplayName = stageDisplayName,
                    stageNumber =  orderNumber,
                    stageZoneName = stageName,
                }

                if isSideStage == true then
                    local stage = ExtraStage.New(database, stageConfig, stagelogger, initData, spawnManager)
                    stage:AddStageCompleteListener(self)

                    if SideStageByIndex[tostring(orderNumber)] == nil then SideStageByIndex[tostring(orderNumber)] = {} end
                    table.insert(SideStageByIndex[tostring(orderNumber)], stage) 
                else 
                    local stage = PrimaryStage.New(database, stageConfig, stagelogger, initData, spawnManager)
                    stage:AddStageCompleteListener(self)
                    
                    if StagesByIndex[tostring(orderNumber)] == nil then StagesByIndex[tostring(orderNumber)] = {} end
                    table.insert(StagesByIndex[tostring(orderNumber)], stage) 
                end 
            end
        end

        if Util.startswith(stageName, "waitingstage", true) then
            local valid = true

            local split = Util.split_string(stageName, "_")

            if Util.tableLength(split) < 3 then
                MissionEditorWarnings.Add("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if valid == true then
                local stageIndexString = split[2]
                local stageIndex = tonumber(stageIndexString)

                if not stageIndex then
                    MissionEditorWarnings.Add("Stage zone with name " .. stageName .. " does not have a valid order number")
                    valid = false
                end

                local waitingSecondsString = split[3]
                local waitingSeconds = tonumber(waitingSecondsString)
                if not waitingSeconds then
                    MissionEditorWarnings.Add("Waiting Stage zone with name " .. stageName .. " does not have a valid amount of seconds parameter")
                    valid = false
                end

                if valid == true then 
                    local stagelogger = Logger.new(stageName, logLevel)

                    ---@type WaitingStageInitData
                    local initData = {
                        stageDisplayName = "Waiting Stage " .. stageIndex,
                        stageNumber =  stageIndex or -99,
                        stageZoneName = stageName,
                        waitingSeconds = waitingSeconds --[[@as integer]]
                    }
                    local waitingStage = WaitingStage.New(database, stageConfig, stagelogger, initData, spawnManager)

                    if WaitingStagesByIndex[tostring(stageIndex)] == nil then
                        WaitingStagesByIndex[tostring(stageIndex)] = {}
                    end
                    table.insert(WaitingStagesByIndex[tostring(stageIndex)], waitingStage)

                    waitingStage:AddStageCompleteListener(self)
                end
            end
        end
    end

    return self
end

function GlobalStageManager:OnStageComplete(stage)
    self.logger:debug("Receiving stage complete event from: " .. stage.zoneName)

    local anyIncomplete = false
    self.logger:debug("Checking stages for index: " .. tostring(currentStage))
    for index, stage in pairs(StagesByIndex[tostring(currentStage)]) do
        if stage:IsComplete() == false then
            anyIncomplete = true
            self.logger:debug("Need to wait for Stage " .. stage.zoneName .. " to be completed")
        else
            self.logger:debug("Stage verified to be completed:  " .. stage.zoneName)
        end
    end

    if anyIncomplete == false and self.stageConfig.isAutoStages == true then

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
            local newStageNumber = currentStage + 1
            self:UpdateDrawings(newStageNumber)
            self.logger:debug("Setting next stage to: " .. tostring(newStageNumber))
            Events.PublishStageNumberChanged(newStageNumber)
        end
    end
end

---@private
function GlobalStageManager:UpdateDrawings(stageNumber)
    local drawings = self.database:getCustomDrawings()
    for _, drawing in pairs(drawings) do
        local startStage, stopStage = drawing:GetStartAndStop()
        if stageNumber >= startStage and stageNumber < stopStage then
            drawing:Draw()
        else
            drawing:Remove()
        end
    end
end


GlobalStageManager.printFullOverview = function ()
    
    local logger = Logger.new("StageOverview", "INFO")
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

return GlobalStageManager
