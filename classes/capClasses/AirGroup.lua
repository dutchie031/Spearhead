

---@class AirGroup
---@field groupName string
---@field groupState GroupState 
local AirGroup = {}

---@alias GroupState
---| "UnSpawned"
---| "ReadOnTheRamp
---| "InTransit"
---| "OnStation"
---| "RtbInTen"
---| "Rtb"
---| "Dead"
---| "Rearming"


---@alias AirGroupType
---| "CAP"

---| "CAS"
---| "SEAD"
---| "INTERCEPT"
---| ""


---@class GroupNameData
---@field type AirGroupType
---@field isBackup boolean
---@field zonesConfig table<string, string>

local function parseGroupName(groupName)

    local split_string = Spearhead.Util.split_string(groupName, "_")
    local partCount = Spearhead.Util.tableLength(split_string)
    
    if partCount >= 3 then

        ---@type boolean
        local isBackup = false

        do -- config
        
        
        end

    else
        Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
        return nil
    end


end


---comment
---@generic T: AirGroup
---@param o T
---@param groupName string
---@return T
function AirGroup.New(o, groupName)
    AirGroup.__index = AirGroup
    local o = o or {}
    local self = setmetatable(o, AirGroup)

    self.groupName = groupName
    self.groupState = "UnSpawned"



    return self
end

