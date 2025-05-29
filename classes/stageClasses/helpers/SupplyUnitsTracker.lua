
env.info("Spearhead SupplyUnitsTracker loaded")

---@class SupplyUnitsTracker
---@field private _supplyUnitsByName table<string, Unit>
---@field private _cargoInUnits table<string, table<CrateType, number>>
---@field private _logger Logger
---@field private _unitPositions table<string, Vec3>
---@field private _commandsHelper MissionCommandsHelper
---@field private _droppedCrates table<string, StaticObject>
---@field private _registeredHubs table<SupplyHub, boolean>
---@field private _supplyUnitSpawnedListener Array<SupplyUnitSpawnedListener>
local SupplyUnitsTracker = {}
SupplyUnitsTracker.__index = SupplyUnitsTracker

-- A single class tracking all units is more than enough.
local singleton = nil

---comment
---@param logLevel LogLevel
---@return SupplyUnitsTracker
function SupplyUnitsTracker.getOrCreate(logLevel)

    if singleton == nil then
        singleton = setmetatable({}, SupplyUnitsTracker)
        singleton._logger = Spearhead.LoggerTemplate.new("SupplyUnitsTracker", logLevel)
        singleton._unitPositions = {}
        singleton._cargoInUnits = {}
        singleton._supplyUnitsByName = {}
        singleton._droppedCrates = {}
        singleton._registeredHubs = {}

        singleton._commandsHelper = Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.getOrCreate(singleton._logger.LogLevel)
        
        Spearhead.Events.AddOnPlayerEnterUnitListener(singleton)

        ---@param selfA SupplyUnitsTracker
        local function updateTask(selfA, time)

            selfA:Update()
            return time + 15
        end

        timer.scheduleFunction(updateTask, singleton, timer.getTime() + 15)

        ---comment
        ---@param selfA SupplyUnitsTracker
        ---@param time number
        ---@return number
        local function checkUnitsInZone(selfA, time)
            pcall(function()
                selfA:CheckUnitsInZones()
            end)
            return time + 5
        end

        timer.scheduleFunction(checkUnitsInZone, singleton, timer.getTime() + 5)

    end

    return singleton

end

---@param unit Unit
function SupplyUnitsTracker:OnPlayerEntersUnit(unit)
    if unit == nil then return end

    if self:IsSupplyUnit(unit) == true then
        self._supplyUnitsByName[unit:getName()] = unit
        self._cargoInUnits[tostring(unit:getID())] = nil
        self._unitPositions[tostring(unit:getID())] = unit:getPoint()
    end

    for _, listener in pairs(self._supplyUnitSpawnedListener) do
        pcall(function()
            listener:SupplyUnitSpawned(unit)
        end)
    end

end

---@class SupplyUnitSpawnedListener
---@field SupplyUnitSpawned fun(self:SupplyUnitSpawnedListener, unit:Unit)

---@param listener SupplyUnitSpawnedListener
function SupplyUnitsTracker:AddOnSupplyUnitSpawnedListener(listener)
    if listener == nil then return end

    if self._supplyUnitSpawnedListener == nil then
        self._supplyUnitSpawnedListener = {}
    end

    table.insert(self._supplyUnitSpawnedListener, listener)
end

function SupplyUnitsTracker:Update()
    local players = Spearhead.DcsUtil.getAllPlayerUnits()
    for _, player in pairs(players) do
        if player ~= nil and player:isExist() and self:IsSupplyUnit(player) == true then
            self._supplyUnitsByName[player:getName()] = player
        end
    end
end

---@private
---@param unit Unit
function SupplyUnitsTracker:IsSupplyUnit(unit)
    if unit == nil then return false end

    if unit:hasAttribute("Transport helicopters") then
        return true
    end

    if unit:hasAttribute("Helicopters") and unit:hasAttribute("Transports") then
        return true
    end

    return false
end

---comment
---@param unitID number
---@param crateType CrateType
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
---@param crateType CrateType
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

function SupplyUnitsTracker:UpdateWeightForUnit(unitID)

    local weight = 0
    if self._cargoInUnits[tostring(unitID)] then
        for crateType, count in pairs(self._cargoInUnits[tostring(unitID)]) do
            local crateConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(crateType)
            if crateConfig and count then
                weight = weight + (crateConfig.weight * count)
            end
        end
    end
    trigger.action.setUnitInternalCargo(unitID, weight)
end


function SupplyUnitsTracker:CheckUnitsInZones()

    for name, unit in pairs(self._supplyUnitsByName) do
        if unit ~= nil and unit:isExist() == true then
            self._logger:debug("Checking unit: " .. unit:getName())
            local pos = unit:getPoint()

            local group = unit:getGroup()

            for hub, enabled in pairs(self._registeredHubs) do
                if enabled == true then
                    local zone = hub:GetZone()
                    if zone ~= nil then
                        if Spearhead.Util.is3dPointInZone(pos, zone) then
                            self._commandsHelper:MarkUnitInSupplyHub(group:getID())
                        else
                            self._commandsHelper:MarkUnitOutsideSupplyHub(group:getID())
                        end
                    end
                end
            end

            self._unitPositions[unit:getID()] = pos
        end
    end
end

function SupplyUnitsTracker:RegisterHub(hub)
    if hub == nil then return end

    if self._registeredHubs[hub] == nil then
        self._registeredHubs[hub] = true
    end
end


---@param unitID number
---@return table<CrateType, number>?
function SupplyUnitsTracker:GetCargoInUnit(unitID)
    if unitID == nil then return end

    local unitIDStr = tostring(unitID)
    if self._cargoInUnits[unitIDStr] == nil then return end

    return self._cargoInUnits[unitIDStr]
end

---@return table<string, Unit>
function SupplyUnitsTracker:GetUnits()
    return self._supplyUnitsByName
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
    self:UpdateWeightForUnit(unitID)
    
    local cargoConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(crateType)

    if cargoConfig == nil then
        self._logger:error("Invalid crate type: " .. crateType)
        return
    end

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
---@param crateType CrateType  
function SupplyUnitsTracker:UnitRequestCrateLoading(groupID, crateType)

    self._logger:debug("UnitRequestCrateLoading called with groupID: " .. groupID .. " and crateType: " .. crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group ~= nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(crateType)
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

        trigger.action.outTextForUnit(unit:getID(), "Loading crate of type " .. crateType, 13)

        ---@class LoadCargoParams
        ---@field self SupplyUnitsTracker
        ---@field unit Unit
        ---@field groupID number
        ---@field crateType CrateType

        ---@param params LoadCargoParams
        local  LoadCrateTask = function(params)
            
            local loaded = params.self:TryLoadCrateInUnit(params.unit, params.crateType)
            if loaded ~= false then
                trigger.action.outTextForUnit(unit:getID(), "Loaded crate :" .. params.crateType, 10)
            end
        end

        ---@type LoadCargoParams
        local params = {
            self = self,
            unit = unit,
            crateType = crateType,
            groupID = groupID
        }

        timer.scheduleFunction(LoadCrateTask, params, timer.getTime() + 15)

    end
end

---comment
---@param unit Unit
---@param crateType CrateType
---@return boolean
function SupplyUnitsTracker:TryLoadCrateInUnit(unit, crateType)
    
    local crateConfigA = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(crateType)
    if crateConfigA == nil then
        trigger.action.outTextForUnit(unit:getID(), "Invalid crate type: " .. crateType, 5)
        return false
    end

    local currentWeight = 0
    for _, cargo in pairs(self._cargoInUnits) do
        if cargo[crateType] ~= nil then
            currentWeight = currentWeight + (cargo[crateType] * crateConfigA.weight)
        end
    end

    local unitConfig = Spearhead.classes.stageClasses.helpers.supplies.MaxLoadConfig[unit:getTypeName()]
    if unitConfig == nil then
        trigger.action.outTextForUnit(unit:getID(), "Your unit type is not configured for logistics: " .. crateType, 5)
        self._logger:error("Invalid unit type: " .. unit:getTypeName())
        return false
    end
    local maxWeight = unitConfig.maxInternalLoad

    if currentWeight + crateConfigA.weight > maxWeight then
        trigger.action.outTextForUnit(unit:getID(), "Failed to load crate due to it overloading your max weight of: " .. maxWeight .. "kg", 5)
        return false
    end

    self:AddCargoToUnit(unit:getID(), crateType)
    self:UpdateWeightForUnit(unit:getID())

    local group = unit:getGroup()
    if group == nil then return false end
    local groupID = group:getID()
    self._commandsHelper:updateCommandsForGroup(groupID)
    
    return true
end

---Spawns a crate for sling loading
---@param groupID number
---@param crateType CrateType
function SupplyUnitsTracker:UnitRequestCrateSpawn(groupID, crateType)

    local group = Spearhead.DcsUtil.GetPlayerGroupByGroupID(groupID)
    if group == nil then

        local crateConfig = Spearhead.classes.stageClasses.helpers.supplies.SupplyConfigHelper.getSupplyConfig(crateType)
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