---@class SupplyUnitsTracker
---@field private _supplyUnits Array<Unit>
---@field private _cargoInUnits table<string, table<SupplyType, number>>
---@field private _logger Logger
---@field private _unitPositions table<string, Vec3>
---@field private _commandsHelper MissionCommandsHelper
---@field private _droppedCrates table<string, StaticObject>
local SupplyUnitsTracker = {}
SupplyUnitsTracker.__index = SupplyUnitsTracker

-- A single class tracking all units is more than enough.
local singleton = nil

---comment
---@return SupplyUnitsTracker
function SupplyUnitsTracker.getOrCreate()

    if singleton == nil then
        singleton = setmetatable({}, SupplyUnitsTracker)
        singleton._logger = Spearhead.LoggerTemplate.new("SupplyUnitsTracker", "INFO")
        singleton._unitPositions = {}
        singleton._cargoInUnits = {}
        singleton._supplyUnits = {}
        singleton._droppedCrates = {}

        singleton._commandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(singleton._logger.LogLevel)
        
        Spearhead.Events.AddOnPlayerEnterUnitListener(singleton)

        local function updateTask(selfA, time)

            selfA:Update()
            return time + 15
        end
        timer.scheduleFunction(updateTask, singleton, timer.getTime() + 15)
    end

    return singleton

end

---@param unit Unit
function SupplyUnitsTracker:OnPlayerEntersUnit(unit)
    if unit == nil then return end

    if self:IsSupplyUnit(unit) == false then return end
    table.insert(self._supplyUnits, unit)
end

function SupplyUnitsTracker:Update()

    self._supplyUnits = {}
    local players = Spearhead.DcsUtil.getAllPlayerUnits()
    for _, player in pairs(players) do
        if player ~= nil then
            table.insert(self._supplyUnits, player)
        end
    end
end

---@private
function SupplyUnitsTracker:IsSupplyUnit(unit)
    if unit == nil then return false end

    if unit:hasAttribute("Transport helicopters") then
        return true
    end

    return false
end

---comment
---@param unitID number
---@param crateType SupplyType
function SupplyUnitsTracker:AddCargoToUnit(unitID, crateType)

    if unitID == nil or crateType == nil then return end

    local unit = Spearhead.DcsUtil.GetPLayerUnitByID(unitID)
    if unit == nil then return end

    if self._cargoInUnits[unitID] == nil then
        self._cargoInUnits[unitID] = {}
    end

    if self._cargoInUnits[unitID][crateType] == nil then
        self._cargoInUnits[unitID][crateType] = 0
    end

    self._cargoInUnits[unitID][crateType] = self._cargoInUnits[unitID][crateType] + 1

end

---@param unitID number
---@param crateType SupplyType
function SupplyUnitsTracker:RemoveCargoFromUnit(unitID, crateType)

    if unitID == nil or crateType == nil then return end

    local unitIDStr = tostring(unitID)
    if self._cargoInUnits[unitIDStr] == nil then return end

    if self._cargoInUnits[unitIDStr][crateType] == nil then return end

    self._cargoInUnits[unitIDStr][crateType] = self._cargoInUnits[unitIDStr][crateType] - 1

    local hasCargo = false
    for type, count in pairs(self._cargoInUnits[unitIDStr]) do
        if count > 0 then
            hasCargo = true
            break
        end
    end
    if hasCargo == false then
        self._cargoInUnits[unitIDStr] = nil
    end

end

---@param unitID number
---@return table<SupplyType, number>?
function SupplyUnitsTracker:GetCargoInUnit(unitID)
    if unitID == nil then return end

    local unitIDStr = tostring(unitID)
    if self._cargoInUnits[unitIDStr] == nil then return end

    return self._cargoInUnits[unitIDStr]
end

---@return Array<Unit>
function SupplyUnitsTracker:GetUnits()
    return self._supplyUnits
end

local cargoCount = 0
function SupplyUnitsTracker:UnloadRequested(unitID, crateType)
    
    self._logger:debug("Unload requested for unit: " .. unitID .. " crateType: " .. crateType)

    local unit = Spearhead.DcsUtil.GetPLayerUnitByID(unitID)
    if unit == nil or unit:isExist() == false then return end
    local group = unit:getGroup()
    if group == nil then
        return
    end

    self:RemoveCargoFromUnit(unitID, crateType)
    
    local cargoConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[crateType]

    local cargoPos = self:GetCargoPlacePosition(unit)

    cargoCount = cargoCount + 1
    local cargoSpawnObject = {
        name = crateType .. "_" .. cargoCount,
        type = cargoConfig.staticType,
        x = cargoPos.x,
        y = cargoPos.z,
    }

    local spawned = coalition.addStaticObject(unit:getCoalition(), cargoSpawnObject)

    self._droppedCrates[cargoSpawnObject.name] = spawned
    self._commandsHelper:updateCommandsForGroup(group:getID())
end

---@return table<string,StaticObject>
function SupplyUnitsTracker:GetCargoCratesDropped()
    return self._droppedCrates
end

---Loads a crate directly into the unit
---@param groupID number
---@param crateType SupplyType  
function SupplyUnitsTracker:UnitRequestCrateLoading(groupID, crateType)

    self._logger:debug("UnitRequestCrateLoading called with groupID: " .. groupID .. " and crateType: " .. crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group ~= nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[crateType]
        if crateConfig == nil then
            self._logger:error("Invalid crate type: " .. crateType)
            return
        end

        local unit = group:getUnit(1)
        
        if unit == nil then return end
        if unit:isExist() == false then return end

        
        if unit:inAir() == true then
            trigger.action.outTextForUnit(unit:getID(), "Land first before crates can be loaded", 10)
            return
        end

        trigger.action.outTextForUnit(unit:getID(), "Loading crate of type " .. crateType, 3)

        trigger.action.setUnitInternalCargo(unit:getName(), crateConfig.weight)
        self:AddCargoToUnit(unit:getID(), crateType)
        self._commandsHelper:updateCommandsForGroup(groupID)
        trigger.action.outTextForUnit(unit:getID(), "Loaded crate of type " .. crateType, 10)
        self._logger:debug("Loaded crate of type " .. crateType .. " into unit " .. unit:getName())

    end
end

---Spawns a crate for sling loading
---@param groupID number
---@param crateType SupplyType
function SupplyUnitsTracker:UnitRequestCrateSpawn(groupID, crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.SupplyConfig[crateType]
        if crateConfig == nil then
            self._logger:error("Invalid crate type: " .. crateType)
            return
        end

        

    end
end


---@private
---@param unit Unit
---@return Vec3
function SupplyUnitsTracker:GetCargoPlacePosition(unit)

    local pos = unit:getPosition()
    local preferedPos = {
        x = pos.p.x - 10 * pos.x.x,
        y = pos.p.y - 10 * pos.x.y,
        z = pos.p.z - 10 * pos.x.z
    }

    return preferedPos


    -- local volume = {
    --     id = world.VolumeType.SPHERE,
    --     params = {
    --         point = preferedPos,
    --         radius = 10
    --     }
    -- }

    -- local occupiedPosX = {}
    -- local occupiedPosZ = {}

    -- ---@param foundItem Object
    -- local found = function(foundItem, val)

    --     local foundPos = foundItem:getPoint()

    --     local z = math.floor(foundPos.z)
    --     for i = z - 3 , z + 3 do
    --         occupiedPosZ[i] = true
    --     end

    --     local x = math.floor(foundPos.x)
    --     for i = x - 3 , x + 3 do
    --         occupiedPosX[i] = true
    --     end
    -- end

    -- world.searchObjects(volume.id, volume.params, found)

    
    
end



if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.SupplyUnitsTracker = SupplyUnitsTracker