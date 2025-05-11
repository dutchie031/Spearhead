

---@class BuildableMission
---@field private _requiredCrates number
---@field private _targetZoneName string
---@field private _database Database
---@field private _onCrateDroppedOfListeners Array<OnCrateDropperListener>
local BuildableMission = {}
BuildableMission.__index = BuildableMission

---@class OnCrateDropperListener 
---@field onCrateDroppedOf fun(self:OnCrateDropperListener, mission:BuildableMission)

---@param database Database
---@param targetZoneName string
---@param requiredCrates number
function BuildableMission.new(database, targetZoneName, requiredCrates)

    local self = setmetatable({}, { __index = BuildableMission })
    self._targetZoneName = targetZoneName
    self._database = database
    self._requiredCrates = requiredCrates

    self._onCrateDroppedOfListeners = {}

    

    return self

end

function BuildableMission:AddOnCrateDroppedOfListener(listener)
    table.insert(self._onCrateDroppedOfListeners, listener)
end

function BuildableMission:NotifyCrateDroppedOf()
    for _, listener in ipairs(self._onCrateDroppedOfListeners) do
        if listener.onCrateDroppedOf then
            listener:onCrateDroppedOf(self)
        end
    end
end



if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.BuildableMission = BuildableMission