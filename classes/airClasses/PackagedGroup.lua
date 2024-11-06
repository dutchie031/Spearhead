local PackagedGroup = {}

---comment
---@param AttackGroup table
---@param EscortGroup table
---@param attackZoneName table minimum { x, z, radius }
---@param attackType any Spearhead.internal.Air.AttackGroupType
---@return table? package
function PackagedGroup:newAttackPackage(AttackGroup, EscortGroup, attackZoneName, attackType, logger)
    local o = {}
    setmetatable(o, { __index = self })

    local attackZone = Spearhead.DcsUtil.getZoneByName(attackZoneName)
    if attackZone == nil then
        logger:warn("Tried to create a package with non-existing attackZone")
        return nil
    end

    AttackGroup.state = Spearhead.internal.Air.GroupState.PACKAGED
    EscortGroup.state = Spearhead.internal.Air.GroupState.PACKAGED

    o.AttackGroup = AttackGroup
    o.EscortGroup = EscortGroup
    o.attackZoneName = attackZoneName
    o.attackZone = attackZone
    o.attackType = attackType
    o.originAirbaseId = AttackGroup.airbaseId
    o.base = Spearhead.DcsUtil.getAirbaseById(o.originAirbaseId)
    o.isActive = false
    o.logger = logger

    o.AlertIDs = {
        EscortOnMarshalAlertId = Spearhead.Util.createUUID(),
        AttackOnMarshalAlertId = Spearhead.Util.createUUID()
    }

    local function getDist(a, b)
        return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
    end

    local distance = getDist(attackZone, o.base:getPoint())

    local marshalPointOffset = distance
    if distance < 148160 then -- if the distance is below 60 nautical miles change the marshal point to just outside of the airbase
        marshalPointOffset = 1000 
    else
        marshalPointOffset = 64820
    end

    local intitialPointDistance = 9260 -- 5 nm
    if o.attackType == Spearhead.internal.Air.AttackGroupType.SEAD then
        intitialPointDistance = 27780   -- 15nm
    elseif o.attackType == Spearhead.internal.Air.AttackGroupType.STRIKE then
        intitialPointDistance = 9260 --5nm
    end

    o.marshalPoint = Spearhead.Util.getClosestPointOnCircle(o.base:getPoint(), marshalPointOffset, attackZone)
    o.initialAttackPoint = Spearhead.Util.getClosestPointOnCircle(attackZone, intitialPointDistance, o.base:getPoint())

    if o.attackType == Spearhead.internal.Air.AttackGroupType.SEAD then
        o.escortOrbitPoint = Spearhead.Util.getClosestPointOnCircle(attackZone, intitialPointDistance + 27780, o.base:getPoint())
    else
        o.escortOrbitPoint = Spearhead.Util.getClosestPointOnCircle(attackZone, intitialPointDistance + 9260, o.base:getPoint())
    end
    
    

    o.SendOut = function(self)
        self.isActive = true
        self.logger:debug("Sending out packaged group with groups: " ..
        o.AttackGroup.groupName .. " | " .. o.EscortGroup.groupName)
        self:SendToMarshal(self.EscortGroup, self.AlertIDs.EscortOnMarshalAlertId)
    end

    o.SendToMarshal = function(self, group, onMarshalAlertId)
        local speed = 250
        local alt = 4000

        local base = Spearhead.DcsUtil.getAirbaseById(group.airbaseId) or
        Spearhead.DcsUtil.getAirbaseById(self.originAirbaseId)
        if base then
            local takeoffPoint = Spearhead.Util.getClosestPointOnCircle(base:getPoint(), 3000, self.attackZone)
            local marshalMission = {
                id = "Mission",
                params = {
                    airborne = true,
                    route = {
                        points = {
                            [1] = Spearhead.RouteUtil.Tasks.FlyOverPointTask(takeoffPoint, 2000, speed, {}),
                            [2] = Spearhead.RouteUtil.Tasks.FlyOverPointTask(self.marshalPoint, alt, speed, {
                                [1] = {
                                    enabled = true,
                                    auto = false,
                                    id = "WrappedAction",
                                    number = 1,
                                    params = {
                                        action = {
                                            id = "Script",
                                            params = {
                                                command = "pcall(Spearhead.Events.TriggerAlert, '" .. onMarshalAlertId .. "')"
                                            }
                                        }
                                    }
                                }
                            }),
                            [3] = Spearhead.RouteUtil.Tasks.OrbitAtPointTask(group.groupName, self.marshalPoint, speed, alt),
                            [4] = Spearhead.RouteUtil.Tasks.RtbTask(group.airbaseId, base:getPoint(), speed)
                        }
                    }
                }
            }

            local dcsGroup = Group.getByName(group.groupName)
            if dcsGroup then
                for _, unit in pairs(dcsGroup:getUnits()) do
                    Spearhead.Events.addOnUnitTakenOffListener(unit:getName(), self)
                end
            end
            Spearhead.Events.AddAlertListener(onMarshalAlertId, self)
            Spearhead.Events.addOnGroupRTBListener(group.groupName, self)

            group:SetTask(marshalMission)
        else
            --[[
                TODO: LOGGING
            ]]
        end
    end

    o.SendFighterFromMarshalPoint = function(self)
        local base = Spearhead.DcsUtil.getAirbaseById(self.EscortGroup.airbaseId) or Spearhead.DcsUtil.getAirbaseById(self.originAirbaseId)
        local sweepAndEscortTask = {
            id = "Mission",
            params = {
                airborne = true,
                route = {
                    points = {
                        [1] = Spearhead.RouteUtil.Tasks.FlyOverPointTask(self.initialAttackPoint, 5000, 250, {
                            [2] = {
                                id = 'EngageTargets',
                                params = {
                                    maxDist = 46300, -- +- 25NM
                                    maxDistEnabled = true, -- required to check maxDist
                                    targetTypes = {
                                        [1] = "Planes"
                                    },
                                    priority = 0
                                }
                            },
                        }),
                        [2] = Spearhead.RouteUtil.Tasks.OrbitAtPointTask(self.EscortGroup.groupName, self.escortOrbitPoint, 250,5000),
                        [3] = Spearhead.RouteUtil.Tasks.RtbTask(self.EscortGroup.airbaseId, base:getPoint(), 250)
                    }
                }
            }
        }
        self.EscortGroup:SetTask(sweepAndEscortTask)
    end

    local SendAttackerToStationDelayed = function(self, time)

        if self.attackType == Spearhead.internal.Air.AttackGroupType.CAS then
            self.AttackGroup:SendOutForCas(self.attackZoneName, self.initialAttackPoint)
        elseif self.attackType == Spearhead.internal.Air.AttackGroupType.SEAD then
            self.AttackGroup:SendOutForSead(self.attackZoneName, self.initialAttackPoint)
        end
        return nil
    end

    o.SendRtb = function(self)
        pcall(function() self.AttackGroup:SendRTB() end)
        pcall(function() self.EscortGroup:SendRTB() end)
    end

    o.OnUnitTakenOff = function(self, initiatorUnit, airbase)

        local group = initiatorUnit:getGroup()
        if group then
            local groupName = group:getName()
            if groupName == self.EscortGroup.groupName then
                self:SendToMarshal(self.AttackGroup, self.AlertIDs.AttackOnMarshalAlertId)
            end
        end
    end

    o.HandleAlert = function(self, alertId)
        if self.isActive == false then
            -- don't handle an alert if the package is already inactive
            return
        end

        if alertId == self.AlertIDs.EscortOnMarshalAlertId then
            self.logger:debug("Escort " .. self.EscortGroup.groupName .. " is now at the Marshalling point")
        elseif alertId == self.AlertIDs.AttackOnMarshalAlertId then
            -- START fighter track
            -- START attack track with X seconds delay

            self:SendFighterFromMarshalPoint()
            timer.scheduleFunction(SendAttackerToStationDelayed, self, timer.getTime() + 30)

            self.logger:debug("Escort " .. self.AttackGroup.groupName .. " is now at the Marshalling point")
        end
    end

    o.OnGroupRTB = function(self, groupName)

        if self.isActive == false then
            return
        end

        local sendGroupRtb = function(group, time)
            group:SendRTB()
            return nil
        end

        if self.AttackGroup.groupName == groupName then
            timer.scheduleFunction(sendGroupRtb, self.EscortGroup, timer.getTime() + 120)
        end
    end

    logger:debug("Created new package with groups: " .. o.AttackGroup.groupName .. " | " .. o.EscortGroup.groupName)
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.PackagedGroup = PackagedGroup
