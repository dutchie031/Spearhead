---@class MaxLoadConfig
---@field maxInternalLoad number

---@type table<string, MaxLoadConfig>
local MaxLoadConfig = {
    ["Mi-8MT"] = {
        maxInternalLoad = 4000,
    },
    ["CH-47Fbl1"] = {
        maxInternalLoad = 10000
    },
    ["Mi-24P"] = {
        maxInternalLoad = 2000
    }, 
    ["UH-1H"] = {
        maxInternalLoad = 2000
    }
}

return MaxLoadConfig