

---@class BuildableMission : Mission
---@field private _requiredCrates number
---@field private _crateType SupplyType
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
---@param requiredCrateType SupplyType
function BuildableMission.new(database, targetZoneName, requiredCrates, requiredCrateType)

    local self = setmetatable({}, { __index = BuildableMission })
    self._targetZoneName = targetZoneName
    self._database = database
    self._requiredCrates = requiredCrates

    self._onCrateDroppedOfListeners = {}

    self._crateType = requiredCrateType

    return self

end

function BuildableMission:AddOnCrateDroppedOfListener(listener)
    table.insert(self._onCrateDroppedOfListeners, listener)
end

---@private
function BuildableMission:NotifyCrateDroppedOf()
    for _, listener in ipairs(self._onCrateDroppedOfListeners) do
        if listener.onCrateDroppedOf then
            listener:onCrateDroppedOf(self)
        end
    end
end

function BuildableMission:SpawnActive()
    
end

function BuildableMission:SpawnForwardUnits()

end

function BuildableMission:CheckCratesInZone()

    ---@type Array<Object>
    local foundCrates = {}

    do 
        ---comment
        ---@param object Object
        ---@param requiredType SupplyType
        local foundFunction = function(object, requiredType)
            local type = Spearhead.classes.stageClasses.helpers.SupplyConfigHelper.fromObjectName(object:getName())
            if type == requiredType then 
                table.insert(foundCrates, object)
            end
        end

        local zone = Spearhead.DcsUtil.getZoneByName(self._targetZoneName)

        if zone == nil then
            Spearhead.LoggerTemplate.new("BuildableMission", "ERROR"):error("Zone not found: " .. self._targetZoneName)
            return
        end

        local y = land.getHeight(zone.location)

        ---@type Sphere
        local searchVolume = {
            id = world.VolumeType.SPHERE,
            params = {
                point = { x = zone.location.x, y = y, z = zone.location.y },
                radius = 1000,
            }
        }
        world.searchObjects(Object.Category.STATIC, searchVolume, foundFunction, self._crateType)
    end
    
    for _, foundCrate in pairs(foundCrates) do 

        foundCrate:destroy()
        self:NotifyCrateDroppedOf()

    end

end


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.BuildableMission = BuildableMission