

local StagesByName = {}
local StagesByIndex = {}


GlobalStageManager = {}
function GlobalStageManager:NewAndStart(database, stageConfig)
    local logger = Spearhead.LoggerTemplate:new("StageManager", stageConfig.logLevel)
    local o = {}
    setmetatable(o, { __index = self })

    o.logger = logger

    o.onStageCompleted = function(self, stage) 
        local stageNumber = tostring(stage.stageNumber)
        local anyActive = false
        for _, stage in pairs(StagesByIndex[stageNumber] or {}) do
            if stage.isActive then anyActive = true end
        end

        if anyActive == false and stageConfig:isAutoStages() == true then
            Spearhead.Events.PublishStageNumberChanged(tonumber(stageNumber) + 1)
        end

    end

    for _, stageName in pairs(database:getStagezoneNames()) do

        local stagelogger = Spearhead.LoggerTemplate:new(stageName, stageConfig.logLevel)
        local stage = Spearhead.internal.Stage:new(stageName, database, stagelogger, stageConfig)

        if stage then
            stage:AddStageCompleteListener(o);
            StagesByName[stageName]  = stage
            local indexString = tostring(stage.stageNumber)
            if StagesByIndex[indexString] == nil then StagesByIndex[indexString] = {} end
            table.insert(StagesByIndex[indexString], stage)
            logger:info("Initiated " .. Spearhead.Util.tableLength(StagesByName) .. " airbases for cap")
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
        if stage.isComplete == false then
            return false
        end
    end

    return true
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalStageManager = GlobalStageManager
