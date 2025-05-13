
---@alias SupplyType
---| "FARP_CRATE"
---| "SAM_CRATE"

---@class SupplyConfig
---@field weight number
---@field staticType string

---@type table<SupplyType, SupplyConfig>
local SupplyConfig = {
    ["FARP_CRATE"] = {
        weight = 1000,
    },
    ["SAM_CRATE"] = {
        weight = 1000,
    },
}

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyConfig = SupplyConfig

