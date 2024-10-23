

local AttackGroup = {}

function AttackGroup:new(groupName, redAirbase, logger, database, casConfig)
    local o = {}
    setmetatable(o, { __index = self })

    local RESPAWN_AFTER_TOUCHDOWN_SECONDS = 180

    Spearhead.DcsUtil.DestroyGroup(groupName)

    o.groupName = groupName
    o.airbaseId = redAirbase.airbaseId
    o.logger = logger
    o.database = database
    o.casConfig = casConfig
    o.state = Spearhead.internal.Air.GroupState.UNSPAWNED
    
    local parsed = Spearhead.internal.Air.ParseAttackGroupName(groupName)
    if parsed == nil then return nil end
    o.type = parsed.attackGroupType
    o.zoneConfig = parsed.zonesConfig

    o.aliveUnits = {}
    o.landedUnits = {}
    o.unitCount = 0
    o.markedForDespawn = false

    o.GetTargetZone = function (self, activateStage)
        return self.zoneConfig[tostring(activateStage)]
    end

    o.SetState = function(self, state)
        self.state = state
        self:PublishUnitUpdatedEvent()
    end

    o.SpawnOnTheRamp = function(self)
        self.markedForDespawn = false
        self.logger:debug("Spawning group " .. self.groupName)
        self.aliveUnits = {}
        self.landedUnits = {}
        
        local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName, nil, nil, true)
        if group then
            self.unitCount = group:getInitialSize()

            if self.state == Spearhead.internal.Air.GroupState.UNSPAWNED then
                self:SetState(Spearhead.internal.Air.GroupState.READYONRAMP)
            end

            for _, unit in pairs(group:getUnits()) do
                local name = unit:getName()
                self.aliveUnits[name] = true
                self.landedUnits[name] = false
            end
        end
    end

    ---comment
    ---@param input table { groupName, task, logger }
    ---@param time number
    ---@return nil
    local function setTaskAsync(input, time)
        local task = input.task
        local groupName = input.groupName
        local group = Group.getByName(groupName)

        if task then
            group:getController():setTask(task)
            if input.logger ~= nil then
                input.logger:debug("task set succesfully to group " .. groupName)
            end
        end
        return nil
    end

    o.SendOutForCas = function(self, targetZoneName, initialPoint)
        self.logger:debug("Sending cas group out. GroupName: " .. self.groupName)
        self:SetState(Spearhead.internal.Air.GroupState.INTRANSIT)

        local attackZone = Spearhead.DcsUtil.getZoneByName(targetZoneName)
        local group = Group.getByName(self.groupName)
        local base = Spearhead.DcsUtil.getAirbaseById(self.airbaseId)

        if group and attackZone and group:isExist() == true and base then
            local points = {}
            local casInZonePoints = Spearhead.RouteUtil.Tasks.CasInZonePoints(self.groupName, {x = attackZone.x, z = attackZone.z}, attackZone.radius or 1000, 2000, 180, 600, initialPoint, "Circle")
            for _, casInZonePoint in pairs(casInZonePoints) do
                table.insert(points, casInZonePoint)
            end
            
            table.insert(points, Spearhead.RouteUtil.Tasks.RtbTask(self.airbaseId, base:getPoint(), 250))
            
            local task = {
                id = "Mission",
                params = {
                    airborne = true,
                    route = {
                        points = points
                    }
                }
            }

            self.logger:debug(task)

            group:getController():setCommand({
                id = 'Start',
                params = {}
            })

            timer.scheduleFunction(setTaskAsync, { task = task, groupName = self.groupName, logger = self.logger }, timer.getTime() + 2)
        else
            self.logger:warn("Could not send group out for cas. " .. self.groupName .. " to " .. targetZoneName)
        end
    end 

    o.SendOutForSead = function(self, targetZoneName, initialPoint)
        self.logger:debug("Sending sead group out. GroupName: " .. self.groupName)
        self:SetState(Spearhead.internal.Air.GroupState.INTRANSIT)

        local attackZone = Spearhead.DcsUtil.getZoneByName(targetZoneName)
        local group = Group.getByName(self.groupName)
        local base = Spearhead.DcsUtil.getAirbaseById(self.airbaseId)

        if group and attackZone and group:isExist() == true and base then
            local points = {}
            local seadInZoneTasks = Spearhead.RouteUtil.Tasks.SeadInZonePoints(self.groupName, {x = attackZone.x, z = attackZone.z}, attackZone.radius or 1000, 2000, 180, 600, initialPoint, "Circle")
            for _, seadInZoneTask in pairs(seadInZoneTasks) do
                table.insert(points, seadInZoneTask)
            end
            
            table.insert(points, Spearhead.RouteUtil.Tasks.RtbTask(self.airbaseId, base:getPoint(), 250))
            
            local task = {
                id = "Mission",
                params = {
                    airborne = true,
                    route = {
                        points = points
                    }
                }
            }

            self.logger:debug(task)

            group:getController():setCommand({
                id = 'Start',
                params = {}
            })

            timer.scheduleFunction(setTaskAsync, { task = task, groupName = self.groupName, logger = self.logger }, timer.getTime() + 2)
        else
            self.logger:warn("Could not send group out for sead. " .. self.groupName .. " to " .. targetZoneName)
        end
    end
    
    ---Sets a task to the group for finer grained control of missions
    ---@param self table
    ---@param task any
    o.SetTask = function(self, task)
        local groupName = self.groupName
        local group = Group.getByName(groupName)

        if group and task then
            group:getController():setCommand({
                id = 'Start',
                params = {}
            })

            timer.scheduleFunction(setTaskAsync, { task = task, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
            self.logger:debug("task set succesfully to group " .. groupName)
        end
    end

    o.SendRTB = function(self)
        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            local speed = math.random(self.casConfig:getMinSpeed(), self.casConfig:getMaxSpeed())
            local task, error = Spearhead.RouteUtil.CreateRTBMission(self.groupName, self.airbaseId, speed)
            if task then
                timer.scheduleFunction(setTaskAsync, { task = task, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
            else 
                self.logger:error("No RTB task could be created for group: " ..
                self.groupName .. " due to " .. error)
                if self.markedForDespawn == true then
                    self:Despawn()
                end
            end
        end
    end

    o.SendRTBAndDespawn = function(self)
        self.markedForDespawn = true
        self:SendRTB()
    end

    o.eventListeners = {}
    ---comment
    ---@param self table
    ---@param listener table object with  function OnGroupStateUpdated(capGroupTable)
    o.AddOnStateUpdatedListener = function(self, listener)
        if type(listener) ~= "table" then
            self.logger:error("Listener not of type table for AddOnStateUpdatedListener")
            return
        end

        if listener.OnGroupStateUpdated == nil then
            self.logger:error("Listener does not implement OnGroupStateUpdated")
            return
        end
        table.insert(self.eventListeners, listener)
    end

    o.PublishUnitUpdatedEvent = function(self)
        for _, callable in pairs(self.eventListeners) do
            local _, error = pcall(function()
                callable:OnGroupStateUpdated(self)
            end)
            if error then
                self.logger:error(error)
            end
        end
    end

    ---comment
    ---@param self table
    ---@param proActive boolean Will check all units in group for aliveness
    o.UpdateState = function(self, proActive)
        local landed = false
        local landedCount = 0
        for name, landedBool in pairs(self.landedUnits) do
            if landedBool == true then
                landedCount = landedCount + 1
                landed = true
            end
        end

        local deadCount = 0
        for name, isAlive in pairs(self.aliveUnits) do
            if isAlive == false then
                deadCount = deadCount + 1
            end
        end

        local function DelayedStartRearm(input, time)
            local attackGroup = input.self
            attackGroup:StartRearm()
        end

        if landedCount + deadCount == self.unitCount then
            if landed then
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    timer.scheduleFunction(DelayedStartRearm, { self = self },
                        timer.getTime() + RESPAWN_AFTER_TOUCHDOWN_SECONDS)
                end
            else
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    local delay = self.casConfig:getDeathDelay() - self.casConfig:getRearmDelay() +
                    RESPAWN_AFTER_TOUCHDOWN_SECONDS
                    timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + delay)
                end
            end
        end
    end

    o.OnUnitLanded = function(self, initiatorUnit, airbase)
        if airbase then
            local airdomeId = airbase:getID()
            self.airbaseId = airdomeId
        end
        local name = initiatorUnit:getName()
        self.logger:debug("Received unit land event for unit " .. name .. " of group " .. self.groupName)

        self.landedUnits[name] = true
        self:UpdateState(false)
    end

    o.OnUnitLost = function(self, initiatorUnit)
        self.logger:debug("Received unit lost event for group " .. self.groupName)
        if initiatorUnit then
            self.aliveUnits[initiatorUnit:getName()] = false
        end
        self:UpdateState(false)
    end

    local units = Group.getByName(groupName):getUnits()
    for key, unit in pairs(units) do
        Spearhead.Events.addOnUnitLandEventListener(unit:getName(), o)
        Spearhead.Events.addOnUnitLostEventListener(unit:getName(), o)
    end

    return o
end



if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.AttackGroup = AttackGroup
