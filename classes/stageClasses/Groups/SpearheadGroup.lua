


---@class SpearheadGroup : OnUnitLostListener
---@field groupName string
---@field private _isStatic boolean
---@field private _isSpawned boolean
local SpearheadGroup = {}

function SpearheadGroup.New(groupName)

    SpearheadGroup.__index = SpearheadGroup

    local o = {}
    local self = setmetatable(o, SpearheadGroup)

    self._isStatic = Spearhead.DcsUtil.IsGroupStatic(groupName) == true
    self.groupName = groupName
    self._isSpawned = false

    return self
end

function SpearheadGroup:SpawnCorpsesOnly()

    if self._isSpawned == true then return end

    local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName)
    if group then
        for _, unit in pairs(group:getUnits()) do
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())
            Spearhead.DcsUtil.DestroyUnit(self.groupName, unit:getName())
            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
            end
        end
    end

    self._isSpawned = true

end

---@param lateStart boolean?
function SpearheadGroup:Spawn(lateStart)

    if self._isSpawned == true then return end

    local spawned, isStatic = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName, nil, nil, lateStart)
    if spawned and isStatic == false then
        for _, unit in pairs(spawned:getUnits()) do
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.DestroyUnit(self.groupName, unit:getName())
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
            else
                Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
            end

            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
        end
    elseif spawned and isStatic == true then
        if spawned then
            Spearhead.Events.addOnUnitLostEventListener(spawned:getName(), self)
        end
    else
        Spearhead.LoggerTemplate.new("SPEARHEADGROUP", "ERROR"):error("Failed to spawn group: " .. self.groupName)
    end

    self._isSpawned = true
end

function SpearheadGroup:Activate()
    
    if self._isStatic == true then return end

    local group = Group.getByName(self.groupName)
    if group then 
        group:activate()
        
        local controller = group:getController()
        if controller then
            controller:setCommand({
                id = 'Start',
                params = {}
            })
        end
    end
end

function SpearheadGroup:Destroy()
    self._isSpawned = false
    Spearhead.DcsUtil.DestroyGroup(self.groupName)
end

---@return boolean
function SpearheadGroup:IsStatic()
    return self._isStatic
end


---@return integer
function SpearheadGroup:GetCoalition()
    if self._isStatic == true then
        local object = StaticObject.getByName(self.groupName)
        if object == nil then
            return 0
        end
        return object:getCoalition()
    else
        local group = Group.getByName(self.groupName)
        if group == nil then
            return 0
        end
        return group:getCoalition()
    end
end

function SpearheadGroup:OnUnitLost(object)
    local name = object:getName()
    local pos = object:getPoint()
    local type = object:getDesc().typeName
    local position = object:getPosition()
    local heading = math.atan2(position.x.z, position.x.x)
    local country_id = object:getCountry()
    Spearhead.classes.persistence.Persistence.UnitKilled(name, pos, heading, type, country_id)
end

---comment
---@return table result list of objects
function SpearheadGroup:GetUnits()

    local result = {}
    if self._isStatic == true then
        local staticObject = StaticObject.getByName(self.groupName)
        if staticObject then 
            table.insert(result, staticObject)
        end
    else
        local group = Group.getByName(self.groupName)
        if not group then return {} end
        for _, unit in pairs(group:getUnits()) do
            table.insert(result, unit)
        end 
    end
    return result
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Groups then Spearhead.classes.stageClasses.Groups = {} end
Spearhead.classes.stageClasses.Groups.SpearheadGroup = SpearheadGroup
