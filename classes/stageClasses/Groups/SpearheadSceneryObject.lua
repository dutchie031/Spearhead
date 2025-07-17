---@class SpearheadSceneryObject
---@field private persistentName string The persistent name of the scenery object
---@field private objectID number The ID of the scenery object
---@field private internalObj table
---@field private isDead boolean Indicates if the scenery object is dead
local SpearheadSceneryObject = {}
SpearheadSceneryObject.__index = SpearheadSceneryObject

---comment
---@param objectID number
---@return SpearheadSceneryObject?
function SpearheadSceneryObject.New(objectID)

    local self = setmetatable({}, SpearheadSceneryObject)

    if objectID == nil then
        return nil
    end

    self.persistentName = "SpearheadSceneryObject_" .. objectID
    self.objectID = objectID
    self.isDead = false
    self.internalObj = {
        ["id_"] = objectID
    }

    return self
end

---@return boolean
function SpearheadSceneryObject:IsAlive()

    if Object.isExist(self.internalObj) == false then
        self:MarkDead()
        return false
    end

    if SceneryObject.getLife(self.internalObj) <= 0.10 then
        self:MarkDead()
        return false
    end

    return true
end

---@private
function SpearheadSceneryObject:MarkDead()
    if self.isDead == true then return end
    self.isDead = true
    Spearhead.classes.persistence.Persistence.UnitKilled(self.persistentName, self:GetPoint(), 0, "Scenery")
end

function SpearheadSceneryObject:UpdateStatePersistently()
    if self.isDead == true then
        return
    end

    local state = Spearhead.classes.persistence.Persistence.UnitState(self.persistentName)
    if state and state.isDead == true then
        trigger.action.explosion(self:GetPoint(), 1000)
        self.isDead = true
    end
end


function SpearheadSceneryObject:GetPersistentName()
    return self.persistentName
end

function SpearheadSceneryObject:GetPoint()
    return Object.getPoint(self.internalObj)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Groups then Spearhead.classes.stageClasses.Groups = {} end
Spearhead.classes.stageClasses.Groups.SpearheadSceneryObject = SpearheadSceneryObject
