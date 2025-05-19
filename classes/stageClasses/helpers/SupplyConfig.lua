
---@alias SupplyType
---| "FARP_CRATE"
---| "SAM_CRATE"
---| "AIRBASE_CRATE"

---@alias CrateType
---| "FARP_CRATE_500"
---| "FARP_CRATE_1000"
---| "FARP_CRATE_2000"
---| "SAM_CRATE_500"
---| "SAM_CRATE_1000"
---| "SAM_CRATE_2000"
---| "AIRBASE_CRATE_2000"

---@class SupplyConfig
---@field type SupplyType
---@field weight number
---@field staticType string
---@field displayName string

---@type table<CrateType, SupplyConfig>
local SupplyConfig = {
    ["FARP_CRATE_500"] = {
        type = "FARP_CRATE",
        weight = 500,
        displayName = "FARP Crate (500)",
        staticType = "container_cargo",
    },
    ["FARP_CRATE_1000"] = {
        type = "FARP_CRATE",
        weight = 1000,
        displayName = "FARP Crate (1000)",
        staticType = "container_cargo",
    },
    ["FARP_CRATE_2000"] = {
        type = "FARP_CRATE",
        weight = 2000,
        displayName = "FARP Crate (2000)",
        staticType = "container_cargo",
    },
    ["SAM_CRATE_500"] = {
        type = "SAM_CRATE",
        weight = 1000,
        displayName = "SAM Crate (500)",
        staticType = "container_cargo",
    },
    ["SAM_CRATE_1000"] = {
        type = "SAM_CRATE",
        weight = 1000,
        displayName = "SAM Crate (1000)",
        staticType = "container_cargo",
    },
    ["SAM_CRATE_2000"] = {
        type = "SAM_CRATE",
        weight = 2000,
        displayName = "SAM Crate (2000)",
        staticType = "container_cargo",
    },
    ["AIRBASE_CRATE_2000"] = {
        type = "AIRBASE_CRATE",
        weight = 2000,
        displayName = "Airbase Crate (2000)",
        staticType = "container_cargo",
    },
}

---@class MaxLoadConfig
---@field maxInternalLoad number

---@type table<string, MaxLoadConfig>
MaxLoadConfig = {
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

---@class SupplyConfigHelper
local SupplyConfigHelper = {}

---comment
---@param name string
---@return SupplyConfig?
function SupplyConfigHelper.fromObjectName(name)
    for configName, config in pairs(SupplyConfig) do
        if Spearhead.Util.startswith(name, configName, true) == true then
            return config
        end
    end
    return nil
end

---@param type CrateType
function SupplyConfigHelper.getSupplyConfig(type)
    return SupplyConfig[type]
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
if Spearhead.classes.stageClasses.helpers.supplies == nil then  Spearhead.classes.stageClasses.helpers.supplies = {} end
Spearhead.classes.stageClasses.helpers.supplies.MaxLoadConfig = MaxLoadConfig
Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper = SupplyConfigHelper

