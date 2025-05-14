
---@alias SupplyType
---| "FARP_CRATE"
---| "SAM_CRATE"

---@class SupplyConfig
---@field weight number
---@field staticType string
---@field displayName string

---@type table<SupplyType, SupplyConfig>
local SupplyConfig = {
    ["FARP_CRATE"] = {
        weight = 1000,
        displayName = "FARP Crate",
        staticType = "container_cargo",
    },
    ["SAM_CRATE"] = {
        weight = 1000,
        displayName = "SAM Crate",
        staticType = "container_cargo",
    },
}

---@class SupplyConfigHelper
local SupplyConfigHelper = {}

---comment
---@param name string
---@return SupplyType?
function SupplyConfigHelper.fromObjectName(name)

    if Spearhead.Util.startsWith(name, "FARP_CRATE", true) then
        return "FARP_CRATE"
    elseif Spearhead.Util.startsWith(name, "SAM_CRATE", true) then
        return "SAM_CRATE"
    end
    return nil
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyConfig = SupplyConfig
Spearhead.classes.stageClasses.helpers.SupplyConfigHelper = SupplyConfigHelper

