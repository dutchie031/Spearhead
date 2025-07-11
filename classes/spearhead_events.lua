
local SpearheadEvents = {}
do

    ---@type Logger
    local logger = nil

    ---@param logLevel LogLevel
    SpearheadEvents.Init = function(logLevel)
        logger = Spearhead.LoggerTemplate.new("Events", logLevel)
    end


    local warn = function(text)
        if logger then
            logger:warn(text)
        end
    end

    local logError = function(text)
        if logger then logger:error(text) end
    end

    local logDebug = function(text)
        if logger then logger:debug(text) end
    end

    ---@class OnStageChangedListener
    ---@field OnStageNumberChanged fun(self:OnStageChangedListener, number:integer)

    do -- STAGE NUMBER CHANGED
        local OnStageNumberChangedListeners = {}
        local OnStageNumberChangedHandlers = {}
        ---Add a stage zone number changed listener
        ---@param listener OnStageChangedListener object with function OnStageNumberChanged(self, number)
        SpearheadEvents.AddStageNumberChangedListener = function(listener)
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
            pcall(function ()
                Spearhead.classes.persistence.Persistence.SetActiveStage(newStageNumber)
            end)

            for _, callable in pairs(OnStageNumberChangedListeners) do
                local succ, err = pcall(function()
                    callable:OnStageNumberChanged(newStageNumber)
                end)
                if err then
                    logError(err)
                end
            end

            for _, callable in pairs(OnStageNumberChangedHandlers) do
                local succ, err = pcall(callable, newStageNumber)
                if err then
                    logError(err)
                end
            end
            Spearhead.LoggerTemplate.new("Events", "INFO"):info("Published stage number changed to: " .. tostring(newStageNumber))
            Spearhead.StageNumber = newStageNumber
        end
    end

    ---@class OnWeaponFiredListener
    ---@field OnWeaponFired fun(self:OnWeaponFiredListener, unit:Unit?, weapon:Weapon?, target:Object?)

    ---@type Array<OnWeaponFiredListener>
    local onWeaponFiredListeners = {}

    ---comment
    ---@param weaponFiredListener OnWeaponFiredListener
    SpearheadEvents.AddWeaponFiredListener = function(weaponFiredListener)
        if type(weaponFiredListener) ~= "table" then
            warn("Event handler not of type table/object")
            return
        end

        table.insert(onWeaponFiredListeners, weaponFiredListener)
    end

    local triggerWeaponFired = function(unit, weapon, target)
        for _, callable in pairs(onWeaponFiredListeners) do
            local succ, err = pcall(function()
                callable:OnWeaponFired(unit, weapon, target)
            end)

            if err then
                logError(err)
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

    ---@class OnUnitLostListener
    ---@field OnUnitLost fun(self:OnUnitLostListener, unit:table)

    ---@type table<string,Array<OnUnitLostListener>>
    local OnUnitLostListeners = {}
    ---This listener gets fired for any event that can indicate a loss of a unit.
    ---Such as: Eject, Crash, Dead, Unit_Lost,
    ---@param unitName any
    ---@param unitLostListener OnUnitLostListener 
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
                            logError(err)
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
                            logError(err)
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
                            logError(err)
                        end
                    end
                end
            end
        end
    end

    do -- PLAYER ENTER UNIT
        local playerEnterUnitListeners = {}
        ---comment
        ---@param listener table object with OnPlayerEntersUnit(self, unit)
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
                            callable:OnPlayerEntersUnit(unit)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end
    end

    do -- Ejection events
    
        local unitEjectListeners = {}
        SpearheadEvents.AddOnUnitEjectedListener = function(listener)
            if type(listener) ~= "table" then
                warn("Unit lost Event listener not of type table/object")
                return
            end

            table.insert(unitEjectListeners, listener)
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
                            logError(err)
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

            if object and object.getName then
                logDebug("Receiving death event from: " .. object:getName())
            end
            
            if object and object.getName and OnUnitLostListeners[object:getName()] then
                for _, callable in pairs(OnUnitLostListeners[object:getName()]) do
                    local succ, err = pcall(function()
                        callable:OnUnitLost(object)
                    end)

                    if err then
                        logError(err)
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_EJECTION then
            
        end

        if event.id == world.event.S_EVENT_SHOT then
            
            local shooter = event.initiator
            local weapon = event.weapon
            local target = event.target
            triggerWeaponFired(shooter, weapon, target)

        end

        if event.id == world.event.S_EVENT_MISSION_END then
            Spearhead.classes.persistence.Persistence.UpdateNow()
        end

        local AI_GROUPS = {}

        local function CheckAndTriggerSpawnAsync(unit, time)
            
            local function isPlayer(unit)
                if unit == nil then return false, "unit is nil" end
                if unit.getGroup == nil then return false, 'no get group function in unit object, most likely static' end
                if Object.getCategory(unit) ~= Object.Category.UNIT then
                    return false, "object is not a unit"
                end

                if unit:isExist() ~= true then return false, "unit does not exist" end
                local group = unit:getGroup()
                if group ~= nil then
                    if AI_GROUPS[group:getName()] == true then
                        return false
                    end

                    local players = Spearhead.DcsUtil.getAllPlayerUnits()
                    local unitName = unit:getName()
                    for i, unit in pairs(players) do
                        if unit:getName() == unitName then
                            return true
                        end
                    end
                    AI_GROUPS[group:getName()] = true
                end
                return false, "unit is nil or does not exist"
            end

            if isPlayer(unit) == true then
                local groupId = unit:getGroup():getID()
                SpearheadEvents.TriggerPlayerEntersUnit(unit)
            end

            return nil
        end

        if event.id == world.event.S_EVENT_BIRTH then
            timer.scheduleFunction(CheckAndTriggerSpawnAsync, event.initiator, timer.getTime() + 3)
        end
    end

    world.addEventHandler(e)
end

if Spearhead == nil then Spearhead = {} end
Spearhead.Events = SpearheadEvents