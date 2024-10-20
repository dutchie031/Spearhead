

local AttackGroup = {}

function AttackGroup:new(groupName, redAirbase, logger, database, casConfig)
    local o = {}
    setmetatable(o, { __index = self })

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

    o.SendOutForCas = function(self, stageNumber)

        self.logger:debug("Sending cas group out. GroupName: " .. self.groupName)
        self:SetState(Spearhead.internal.Air.GroupState.INTRANSIT)

        local group = Group.getByName(self.groupName)
        local task = Spearhead.internal.Air.Routing.GetOrCreateCasRoute(self.database, self.groupName, stageNumber, 150, 3000, self.airbaseId, 600)
        if group and group:isExist() and task then
            self.state = Spearhead.internal.Air.GroupState.INTRANSIT
            group:getController():setCommand({
                id = 'Start',
                params = {}
            })
            timer.scheduleFunction(setTaskAsync, { task = task, groupName = self.groupName, logger = self.logger }, timer.getTime() + 1)
            return true
        else
            return false
        end
    end 

    ---Sets a task to the group for finer grained control of missions
    ---@param self table
    ---@param task any
    o.SetTask = function(self, task)
        local groupName = self.groupName
        local group = Group.getByName(groupName)

        if group and task then
            group:getController():setTask(task)
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
    return o
end



if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.AttackGroup = AttackGroup
