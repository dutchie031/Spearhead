

local AttackGroup = {}

function AttackGroup:new(groupName, redAirbase, logger, database, casConfig)
    local o = {}
    setmetatable(o, { __index = self })

    Spearhead.DcsUtil.DestroyGroup(groupName)

    o.groupName = groupName
    o.airbaseId = redAirbase.airbaseId
    o.parentManager = redAirbase
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

    o.SetWaitingForEscort = function (self)
        self.state = Spearhead.internal.Air.GroupState.WAITINGFORESCORT
    end

    o.SendOutForCas = function(self, stageNumber)

        self.logger:debug("Sending cas group out. GroupName: " .. self.groupName)
        self:SetState(Spearhead.internal.Air.GroupState.INTRANSIT)

        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            self.state = Spearhead.internal.Air.GroupState.INTRANSIT
            group:getController():setCommand({
                id = 'Start',
                params = {}
            })
        end
    end

    o.SendRTB = function(self)
        --[[
            TODO
        ]]
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
