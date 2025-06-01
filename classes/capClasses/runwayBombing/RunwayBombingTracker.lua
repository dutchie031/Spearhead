---@class RunwayBombingTracker : OnWeaponFiredListener
---@field trackedRunways table<Runway, RunwayStrikeMission>
---@field private _logger Logger
local RunwayBombingTracker = {}
RunwayBombingTracker.__index = RunwayBombingTracker

--- Constructor
--- @param logger Logger
--- @return RunwayBombingTracker
function RunwayBombingTracker.new(logger)
    local self = setmetatable({}, RunwayBombingTracker)

    self._logger = logger

    Spearhead.Events.AddWeaponFiredListener(self)

    return self
end

---comment
---@param weapon Weapon
function RunwayBombingTracker:OnWeaponFired(unit, weapon, target)

    if weapon == nil then
        return
    end

    local desc = weapon:getDesc()
    local isTrackable = desc.category == Weapon.Category.BOMB or (desc.category == Weapon.Category.MISSILE and desc.missileCategory == Weapon.MissileCategory.CRUISE)
    if isTrackable == true then
        
        ---@type WeaponTrackingArgs
        local weaponTrackingArgs = {
            weapon = weapon,
            self = self
        }

        timer.scheduleFunction(RunwayBombingTracker.trackWeaponTask, weaponTrackingArgs, timer.getTime() + 1)
    end
end

function RunwayBombingTracker:RegisterRunway(runway, strikeMission)
    if not self.trackedRunways then
        self.trackedRunways = {}
    end

    if not self.trackedRunways[runway] then
        self.trackedRunways[runway] = strikeMission
    end
end

---@class WeaponTrackingArgs
---@field weapon Weapon
---@field self RunwayBombingTracker

---@private
---@param weaponTrackingArgs WeaponTrackingArgs
function RunwayBombingTracker.trackWeaponTask(weaponTrackingArgs, time)

    local weapon = weaponTrackingArgs.weapon
    local self = weaponTrackingArgs.self
    
    if not weapon or weapon:isExist() == false then return nil end

    local pos = weapon:getPoint()
    local velocity = weapon:getVelocity()
    local ground = land.getHeight({ x = pos.x, y = pos.z })
    local MpS = velocity.y -- increase the speed to make sure you don't miss it.

    if MpS > 0 then
        return time + 3
    end

    local nextInterval = (pos.y - ground) / math.abs(MpS)

    if nextInterval < 1 then

        -- Calculate the impact point of the weapon
        ---@type Vec2
        local impactPoint = {
            x = pos.x + velocity.x * nextInterval,
            y = pos.z + velocity.z * nextInterval
        }

        
        self:OnWeaponImpact(weapon:getDesc(), impactPoint)

        
        return nil
    end

    if nextInterval > 5 then
        nextInterval = 5
    end

    return time + (nextInterval /2)
end


---comment
---@param weaponDesc table
---@param impactPoint Vec2
function RunwayBombingTracker:OnWeaponImpact(weaponDesc, impactPoint)

    self._logger:debug("RunwayBombingTracker:OnWeaponImpact")

    local warhead = weaponDesc.warhead
    local explosiveMass = warhead.explosiveMass or warhead.shapedExplosiveMass

    for runway, strikeMission in pairs(self.trackedRunways) do

        local zone= strikeMission:GetRunwayZone()

        if Spearhead.Util.is3dPointInZone({ x = impactPoint.x, z = impactPoint.y, y = 0 }, zone) then
            strikeMission:RunwayHit(impactPoint, explosiveMass)
        end
    end
end


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.runwayBombing then Spearhead.classes.capClasses.runwayBombing = {} end
Spearhead.classes.capClasses.runwayBombing.RunwayBombingTracker = RunwayBombingTracker