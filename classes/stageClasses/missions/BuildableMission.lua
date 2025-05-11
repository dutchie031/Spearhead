

---@class BuildableMission
---@field private _requiredCrates number
---@field private _targetZoneName string
---@field private _database Database
---@field private _onCrateDroppedOfListeners Array<
local BuildableMission = {}
BuildableMission.__index = BuildableMission

---@class OnCrateDropperListener 
---@field onCrateDroppedOf function

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


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.BuildableMission = BuildableMission