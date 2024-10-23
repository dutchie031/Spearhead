
local SpearheadEvents = {}
do
    do -- STAGE NUMBER CHANGED
        local OnStageNumberChangedListeners = {}
        local OnStageNumberChangedHandlers = {}


        local warn = function(text)
            env.warn("[Spearhead][Events] " .. (text or "nil"))
        end
    
        local error = function(text)
            env.error("[Spearhead][Events] " .. (text or "nil"))
        end

        ---Add a stage zone number changed listener
        ---@param listener table object with function OnStageNumberChanged(self, number)
        SpearheadEvents.AddStageNumberChangedListener = function(listener)
            if type(listener) ~= "table" then
                warn("Event listener not of type table, did you mean to use handler?")
                return
            end
            table.insert(OnStageNumberChangedListeners, listener)
        end

        ---Add a stage zone number changed listener
        ---@param handler function function(number)
        SpearheadEvents.AddStageNumberChangedHandler = function(handler)
            if type(handler) ~= "function" then
                warn("Event handler not of type function, did you mean to use listener?")
                return
            end
            table.insert(OnStageNumberChangedHandlers, handler)
        end

        ---@param newStageNumber number
        SpearheadEvents.PublishStageNumberChanged = function(newStageNumber)
            for _, callable in pairs(OnStageNumberChangedListeners) do
                local succ, err = pcall(function()
                    callable:OnStageNumberChanged(newStageNumber)
                end)
                if err then
                    error(err)
                end
            end

            for _, callable in pairs(OnStageNumberChangedHandlers) do
                local succ, err = pcall(callable, newStageNumber)
                if err then
                    error(err)
                end
            end
        end
    end

   

    local onLandEventListeners = {}
    ---Add an event listener to a specific unit
    ---@param unitName string to call when the unit lands
    ---@param landListener table table with function OnUnitLanded(self, initiatorUnit, airbase)
    SpearheadEvents.addOnUnitLandEventListener = function(unitName, landListener)
        if type(landListener) ~= "table" then
            warn("Event handler not of type table/object")
            return
        end

        if onLandEventListeners[unitName] == nil then
            onLandEventListeners[unitName] = {}
        end
        table.insert(onLandEventListeners[unitName], landListener)
    end

    local OnUnitLostListeners = {}
    ---This listener gets fired for any event that can indicate a loss of a unit.
    ---Such as: Eject, Crash, Dead, Unit_Lost,
    ---@param unitName any
    ---@param unitLostListener table Object with function: OnUnitLost(initiatorUnit)
    SpearheadEvents.addOnUnitLostEventListener = function(unitName, unitLostListener)
        if type(unitLostListener) ~= "table" then
            warn("Unit lost Event listener not of type table/object")
            return
        end

        if OnUnitLostListeners[unitName] == nil then
            OnUnitLostListeners[unitName] = {}
        end

        table.insert(OnUnitLostListeners[unitName], unitLostListener)
    end

    do -- ON RTB
        local OnGroupRTBListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTB(self, groupName)
        SpearheadEvents.addOnGroupRTBListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBListeners[groupName] == nil then
                OnGroupRTBListeners[groupName] = {}
            end

            table.insert(OnGroupRTBListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishRTB = function(groupName)
            if groupName ~= nil then
                if OnGroupRTBListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTB(groupName)
                        end)
                        if err then
                            error(err)
                        end
                    end
                end
            end
        end

        local OnGroupRTBInTenListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTBInTen(self, groupName)
        SpearheadEvents.addOnGroupRTBInTenListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBInTenListeners[groupName] == nil then
                OnGroupRTBInTenListeners[groupName] = {}
            end

            table.insert(OnGroupRTBInTenListeners[groupName], handlingObject)
        end

        ---Publish the Group is RTB
        ---@param groupName string
        SpearheadEvents.PublishRTBInTen = function(groupName)
            if groupName ~= nil then
                if OnGroupRTBInTenListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBInTenListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTBInTen(groupName)
                        end)
                        if err then
                            error(err)
                        end
                    end
                end
            end
        end
    end

    do -- ON Station
        local OnGroupOnStationListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        SpearheadEvents.addOnGroupOnStationListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupOnStationListeners[groupName] == nil then
                OnGroupOnStationListeners[groupName] = {}
            end

            table.insert(OnGroupOnStationListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishOnStation = function(groupName)
            if groupName ~= nil then
                if OnGroupOnStationListeners[groupName] then
                    for _, callable in pairs(OnGroupOnStationListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupOnStation(groupName)
                        end)
                        if err then
                            error(err)
                        end
                    end
                end
            end
        end
    end

    do     --COMMANDS
        do -- status updates
            local onStatusRequestReceivedListeners = {}
            ---comment
            ---@param listener table object with OnStatusRequestReceived(self, groupId)
            SpearheadEvents.AddOnStatusRequestReceivedListener = function(listener)
                if type(listener) ~= "table" then
                    warn("Unit lost Event listener not of type table/object")
                    return
                end

                table.insert(onStatusRequestReceivedListeners, listener)
            end

            local triggerStatusRequestReceived = function(groupId)
                for _, callable in pairs(onStatusRequestReceivedListeners) do
                    local succ, err = pcall(function()
                        callable:OnStatusRequestReceived(groupId)
                    end)
                end
            end

            SpearheadEvents.AddCommandsToGroup = function(groupId)
                local base = "MISSIONS"
                if groupId then
                    missionCommands.addCommandForGroup(groupId, "Stage Status", nil, triggerStatusRequestReceived,
                        groupId)
                end
            end

        end
    end

    do -- PLAYER ENTER UNIT
        local playerEnterUnitListeners = {}
        ---comment
        ---@param listener table object with OnPlayerEnterUnit(self, unit)
        SpearheadEvents.AddOnPlayerEnterUnitListener = function(listener)
            if type(listener) ~= "table" then
                warn("Unit lost Event listener not of type table/object")
                return
            end

            table.insert(playerEnterUnitListeners, listener)
        end

        SpearheadEvents.TriggerPlayerEntersUnit = function(unit)
            if unit ~= nil then
                if playerEnterUnitListeners then
                    for _, callable in pairs(playerEnterUnitListeners) do
                        local succ, err = pcall(function()
                            callable:OnPlayerEnterUnit(unit)
                        end)
                        if err then
                           error(err)
                        end
                    end
                end
            end
        end
    end

    local e = {}
    function e:onEvent(event)
        if event.id == world.event.S_EVENT_LAND or event.id == world.event.S_EVENT_RUNWAY_TOUCH then
            local unit = event.initiator
            local airbase = event.place
            if unit ~= nil then
                local name = unit:getName()
                if onLandEventListeners[name] then
                    for _, callable in pairs(onLandEventListeners[name]) do
                        local succ, err = pcall(function()
                            callable:OnUnitLanded(unit, airbase)
                        end)
                        if err then
                            error(err)
                        end
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_DEAD or
            event.id == world.event.S_EVENT_CRASH or
            event.id == world.event.S_EVENT_EJECTION or
            event.id == world.event.S_EVENT_UNIT_LOST then
            local object = event.initiator
            if object and object.getName and OnUnitLostListeners[object:getName()] then
                for _, callable in pairs(OnUnitLostListeners[object:getName()]) do
                    local succ, err = pcall(function()
                        callable:OnUnitLost(object)
                    end)

                    if err then
                        error(err)
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
            env.info("blaat player entering unit")
            local groupId = event.initiator:getGroup():getID()
            SpearheadEvents.AddCommandsToGroup(groupId)
        end
    end

    world.addEventHandler(e)
end

if Spearhead == nil then Spearhead = {} end
Spearhead.Events = SpearheadEvents