


---@class SpearheadGroup : OnUnitLostListener
---@field private _groupName string
---@field private _isStatic boolean
---@field private _isSpawned boolean
---@field private _spawnManager SpawnManager
---@field private _isPersistent boolean
local SpearheadGroup = {}
SpearheadGroup.__index = SpearheadGroup

---comment
---@param groupName string
---@param spawnManager SpawnManager
---@param isPersistent boolean?
---@return SpearheadGroup
function SpearheadGroup.New(groupName, spawnManager, isPersistent)
    local self = setmetatable({}, SpearheadGroup)

    if isPersistent == nil then isPersistent = false end

    self._spawnManager = spawnManager
    self._isStatic = Spearhead.DcsUtil.IsGroupStatic(groupName) == true
    self._groupName = groupName
    self._isSpawned = false

    return self
end


function SpearheadGroup:GetName()
    return self._groupName
end

function SpearheadGroup:IsSpawned()
    return self._isSpawned
end

function SpearheadGroup:SpawnCorpsesOnly()

    if self._isSpawned == true then return end
    
    self._spawnManager:SpawnCorpsesOnly(self._groupName)
    self._isSpawned = true

end

---@param lateStart boolean?
function SpearheadGroup:Spawn(lateStart)

    if self._isSpawned == true then return end

    ---@type SpawnOverrides
    local overrides = {
        uncontrolled = lateStart or false,
    }

    local spawnedObject, isStatic = self._spawnManager:SpawnGroup(self._groupName, overrides, self._isPersistent)
    self._isStatic = isStatic
    self._isSpawned = true
end

function SpearheadGroup:Destroy()
    self._isSpawned = false
    self._spawnManager:DestroyGroup(self._groupName)
end

---@return boolean
function SpearheadGroup:IsStatic()
    return self._isStatic
end


---@return integer
function SpearheadGroup:GetCoalition()
    if self._isStatic == true then
        local object = StaticObject.getByName(self._groupName)
        if object == nil then
            return 0
        end
        return object:getCoalition()
    else
        local group = Group.getByName(self._groupName)
        if group == nil then
            return 0
        end
        return group:getCoalition()
    end
end

---comment
---@return table result list of objects
function SpearheadGroup:GetObjects()

    local result = {}
    if self._isStatic == true then
        local staticObject = StaticObject.getByName(self._groupName)
        if staticObject then 
            table.insert(result, staticObject)
        end
    else
        local group = Group.getByName(self._groupName)
        if not group then return {} end
        for _, unit in pairs(group:getUnits()) do
            table.insert(result, unit)
        end 
    end
    return result
end

---comment
---@return Array<Unit> result list of objects
function SpearheadGroup:GetAsUnits()

    if self._isStatic == true then
        return {}
    end

    local result = {}
    local group = Group.getByName(self._groupName)
    if not group then return {} end
    for _, unit in pairs(group:getUnits()) do
        table.insert(result, unit)
    end 
    return result
end

---@return Array<Vec3>
function SpearheadGroup:GetAllUnitPositions()

     local result = {}
    if self._isStatic == true then
        local staticObject = StaticObject.getByName(self._groupName)
        if staticObject then 
            table.insert(result, staticObject:getPoint())
        end
    else
        local group = Group.getByName(self._groupName)
        if not group then return {} end
        for _, unit in pairs(group:getUnits()) do
            table.insert(result, unit:getPoint())
        end 
    end
    return result
end

function SpearheadGroup:SetInvisible()

    if self._isStatic == true then
        local country = Spearhead.DcsUtil.GetNeutralCountry()

        ---@type SpawnOverrides
        local overrides = {
            countryID = country
        }

        self._spawnManager:SpawnGroup(self._groupName, overrides)

        Spearhead.DcsUtil.SpawnGroupTemplate(self._groupName, nil, nil, nil, country)
    else
        local group = Group.getByName(self._groupName)
        if group then
            local setInvisible = {
                id = 'SetInvisible',
                params = {
                    value = true
                }
            }
            group:getController():setCommand(setInvisible)
        end

    end
end


function SpearheadGroup:SetVisible()

    local group = Group.getByName(self._groupName)
    if group then
        local setInvisible = {
            id = 'SetInvisible',
            params = {
                value = false
            }
        }
        group:getController():setCommand(setInvisible)
    end
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Groups then Spearhead.classes.stageClasses.Groups = {} end
Spearhead.classes.stageClasses.Groups.SpearheadGroup = SpearheadGroup
