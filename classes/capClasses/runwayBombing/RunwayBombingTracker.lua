---@class RunwayBombingTracker
---@field trackedRunways table<Runway, RunwayStrikeMission>
local RunwayBombingTracker = {}
RunwayBombingTracker.__index = RunwayBombingTracker

--- Constructor
--- @return RunwayBombingTracker
function RunwayBombingTracker.new()
    local self = setmetatable({}, RunwayBombingTracker)
    return self
end

---comment
---@param weapon Weapon
function RunwayBombingTracker:OnWeaponFired(weapon)

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

---@class WeaponTrackingArgs
---@field weapon Weapon
---@field self RunwayBombingTracker

---@private
---@param weaponTrackingArgs WeaponTrackingArgs
function RunwayBombingTracker.trackWeaponTask(weaponTrackingArgs, time)

    local weapon = weaponTrackingArgs.weapon
    local self = weaponTrackingArgs.self
    
    if not weapon then return nil end

    local pos = weapon:getPoint()
    local velocity = weapon:getVelocity()
    local ground = land.getHeight({ x = pos.x, y = pos.z })
    local MpS = velocity.y * 2 -- increase the speed to make sure you don't miss it.

    if MpS > 0 then
        return time + 3
    end

    local nextInterval = (pos.y - ground) / math.abs(MpS)

    if nextInterval < 0.5 then

        -- Calculate the impact point of the weapon
        ---@type Vec2
        local impactPoint = {
            x = pos.x + velocity.x * nextInterval,
            y = pos.z + velocity.z * nextInterval
        }

        ---@class WeaponImpactArgs
        ---@field weapon Weapon
        ---@field impactPoint Vec2
        ---@field self RunwayBombingTracker
        
        ---@param weaponImpactArgs WeaponImpactArgs
        local function reportImpact(weaponImpactArgs, time)
            weaponImpactArgs.self:OnWeaponImpact(weaponImpactArgs.weapon, weaponImpactArgs.impactPoint)
            return nil
        end

        timer.scheduleFunction(reportImpact, { weapon = weapon, impactPoint = impactPoint, self = self }, time + 5)
        return nil
    end

    if nextInterval > 5 then
        nextInterval = 5
    end

    return time + nextInterval
end


---comment
---@param weapon Weapon
---@param impactPoint Vec2
function RunwayBombingTracker:OnWeaponImpact(weapon, impactPoint)

    local desc = weapon:getDesc()
    local warhead = desc.warhead
    local explosiveMass = warhead.explosiveMass or warhead.shapedExplosiveMass

    for runway, strikeMission in pairs(self.trackedRunways) do

        -- Calculate the 4 corner points of the runway based on heading, height, and width
        local radHeading = math.rad(runway.course)
        local cosH = math.cos(radHeading)
        local sinH = math.sin(radHeading)

        local halfWidth = runway.width / 2
        local halfHeight = runway.length / 2

        ---@type Array<Vec2>
        local corners = {
            {
                x = runway.position.x + (-halfHeight * cosH - halfWidth * sinH),
                y = runway.position.z + (-halfHeight * sinH + halfWidth * cosH)
            },
            {
                x = runway.position.x + (-halfHeight * cosH + halfWidth * sinH),
                y = runway.position.z + (-halfHeight * sinH - halfWidth * cosH)
            },
            {
                x = runway.position.x + (halfHeight * cosH + halfWidth * sinH),
                y = runway.position.z + (halfHeight * sinH - halfWidth * cosH)
            },
            {
                x = runway.position.x + (halfHeight * cosH - halfWidth * sinH),
                y = runway.position.z + (halfHeight * sinH + halfWidth * cosH)
            }
        }

        ---@type Array<Vec2>
        local vert = {
            corners[1],
            corners[2],
            corners[3],
            corners[4]
        }

        ---@type SpearheadTriggerZone
        local zone = {
            location = { x= runway.position.x, y = runway.position.z },
            radius = runway.width,
            name = runway.Name,
            verts = vert,
            zone_type = "Polygon",
        }

        if Spearhead.Util.is3dPointInZone({ x = impactPoint.x, z = impactPoint.y, y = 0 }, zone) then
            strikeMission:RunwayHit(impactPoint, explosiveMass)
        end
    end
end


if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
Spearhead.classes.capClasses.RunwayBombingTracker = RunwayBombingTracker