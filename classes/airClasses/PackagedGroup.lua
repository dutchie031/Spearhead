

local PackagedGroup = {}

---comment
---@param AttackGroup table
---@param EscortGroup table
---@param attackZone table minimum { x, z, radius }
---@param attackType any Spearhead.internal.Air.AttackGroupType 
---@return table package
function PackagedGroup:newAttackPackage(AttackGroup, EscortGroup, attackZone, attackType)

    local o = {}
    setmetatable(o, { __index = self })

    o.AttackGroup = AttackGroup
    o.EscortGroup = EscortGroup
    o.attackZone = attackZone
    o.attackType = attackType
    o.originAirbaseId = AttackGroup.airbaseId
    o.base = Spearhead.DcsUtil.getAirbaseById(o.originAirbaseId)
    o.isActive = false

    o.AlertIDs = {
        OnEscortTakenOffAlertId = Spearhead.Util.createUUID(),
        EscortOnMarshalAlertId = Spearhead.Util.createUUID(),
        AttackTakeoffAlertId = Spearhead.Util.createUUID(),
        AttackOnMarshalAlertId = Spearhead.Util.createUUID()
    }

    local function getDist(a, b)
        return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
    end

    local distance = getDist(attackZone, o.base:getPoint())

    local marshalPointOffset = distance
    if distance > 56327 then
        distance = 56327 --35 miles max
    end

    o.marshalPoint = Spearhead.Util.getClosestPointOnCircle(attackZone, marshalPointOffset, o.base:getPoint())

    o.SendOut = function (self)

        self.isActive = true


    end

    o.SendToMarshal = function(self, group, takeOffAlertId, onMarshalAlertId)
        local speed = 400
        local alt = 4000

        local base = Spearhead.DcsUtil.getAirbaseById(group.airbaseId) or Spearhead.DcsUtil.getAirbaseById(self.originAirbaseId)
        if base then
            local takeoffPoint = Spearhead.Util.getClosestPointOnCircle(base:getPoint(), 3000, self.marshalPoint)

            local marshalMission = {
                id = "Mission", 
                params = {
                    airborne = true,
                    route = {
                        [1] = Spearhead.RouteUtil.Tasks.FlyOverPointTask(takeoffPoint, 1500, speed, {
                            [1] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 1,
                                params = {
                                    action = {
                                        id = "Option",
                                        params = {
                                            id = "Script",
                                            params = {
                                                command = "pcall(Spearhead.Events.TriggerAlert, \"" .. takeOffAlertId .. "\")"
                                            }
                                        }
                                    }
                                }
                            }
                        }),
                        [2] = Spearhead.RouteUtil.Tasks.FlyOverPointTask(group.groupName, alt, speed, {
                            [1] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 1,
                                params = {
                                    action = {
                                        id = "Option",
                                        params = {
                                            id = "Script",
                                            params = {
                                                command = "pcall(Spearhead.Events.TriggerAlert, \"" .. onMarshalAlertId .. "\")"
                                            }
                                        }
                                    }
                                }
                            }
                        }),
                        [3] = Spearhead.RouteUtil.Tasks.OrbitAtPointTask(),
                        [4] = Spearhead.RouteUtil.Tasks.RtbTask(group.airbaseId, base:getPoint(), speed)
                    }
                }
            }

            Spearhead.Events.AddAlertListener(takeOffAlertId, self)
            Spearhead.Events.AddAlertListener(onMarshalAlertId, self)

            group:SetTask(marshalMission)
        else
            --[[
                TODO: LOGGING
            ]]
        end
    end


    o.SendRtb = function(self)
        pcall(function() self.AttackGroup:SendRTB() end)
        pcall(function() self.EscortGroup:SendRTB() end)
    end

    o.HandleAlert = function(self, alertId)
        if self.isActive == false then
            return 
        end
        
        if alertId == self.AlertIDs.OnEscortTakenOffAlertId then
            self:SendToMarshal(self.AttackGroup, self.AlertIDs.AttackTakeoffAlertId, self.AlertIDs.AttackOnMarshalAlertId)
        end

        if alertId == self.AlertIDs.EscortOnMarshalAlertId then
            trigger.action.outText("Escort is now at the Marshalling point", 30)
        end
    end

    return o
end