


local briefingMessageTime = nil

---@class GlobalConfig
---@field private _briefingTime number ;
local GlobalConfig = {}
GlobalConfig.__index = GlobalConfig;

---@return GlobalConfig
function GlobalConfig.New()

    local self = setmetatable({}, GlobalConfig)

    self._briefingTime = 30

    if SpearheadConfig then
        if SpearheadConfig.briefingMessageDuration then
            self._briefingTime = SpearheadConfig.briefingMessageDuration
        end
    end

    return self
end

function GlobalConfig:getBriefingTime()
    return self._briefingTime or 30
end


return GlobalConfig

