


local StageBase = {}

do
    function StageBase:New(databaseManager, logger, airbaseId)

        local o = {}
        setmetatable(o, { __index = self })
    
        o.db = databaseManager
        o.logger = logger

        o.red_groups = {}
        o.blue_groups = {}
        o.cleanup_units = {}

        o.airbase = Spearhead.DcsUtil.getAirbaseById(airbaseId)
        o.initialSide = Spearhead.DcsUtil.getStartingCoalition(airbaseId)

        do --init
            local redUnitsPos = {}
            local blueUnitsPos = {}

            do -- fill tables
              local redGroups = databaseManager:getRedGroupsAtAirbase(airbaseId)
              if redGroups then
                for _, groupName in pairs(redGroups) do
                    
                    table.insert(o.red_groups, groupName)

                    if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                        local staticObject = StaticObject.getByName(groupName)
                        redUnitsPos[staticObject:getName()] = staticObject:getPoint()
                    else
                        local group = Group.getByName(groupName)
                        if group then
                            for _, unit in pairs(group:getUnits()) do
                                redUnitsPos[unit:getName()] = unit:getPoint()
                            end
                        end
                        Spearhead.DcsUtil.DestroyGroup(groupName)
                    end
                end
              end

              local blueGroups = databaseManager:getBlueGroupsAtAirbase(airbaseId)
              if blueGroups then
                for _, groupName in pairs(blueGroups) do
                    
                    table.insert(o.blue_groups, groupName)

                    if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                        local staticObject = StaticObject.getByName(groupName)
                        blueUnitsPos[staticObject:getName()] = staticObject:getPoint()
                    else
                        local group = Group.getByName(groupName)
                        if group then
                            for _, unit in pairs(group:getUnits()) do
                                blueUnitsPos[unit:getName()] = unit:getPoint()
                            end
                        end
                        Spearhead.DcsUtil.DestroyGroup(groupName)
                    end
                end
              end
            end

            do -- check cleanup requirements
                -- Checks is any of the units are withing range (5m) of another unit. 
                -- If so, make sure to add them to the cleanup list.
            
                local cleanup_distance = 5

                for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
                    for redUnitName, redUnitPos in pairs(redUnitsPos) do
                        local distance = Spearhead.Util.VectorDistance(blueUnitPos, redUnitPos)
                        env.info("distance: " .. tostring(distance))
                        if distance <= cleanup_distance then
                            o.cleanup_units[redUnitName] = true
                        end
                    end
                end
            end
        end

        local spawnRedUnits = function(self)
            for _, groupName in pairs(self.red_groups) do
                local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)

                if group then
                    for _, unit in pairs(group:getUnits()) do
                        local unitName = unit:getName()
                        local deathState = Spearhead.internal.Persistence.UnitDeadState(unitName)
                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                        else
                            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                        end
                    end
                end
            end
        end

        local cleanRedUnit = function(self)
            for _, groupName in pairs(self.red_groups) do
                if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                    Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    local staticObject = StaticObject.getByName(groupName)

                    if staticObject then
                        if self.cleanup_units[groupName] then
                            staticObject:destroy()
                        else
                            local unitName = staticObject:getName()
                            local deathState = Spearhead.internal.Persistence.UnitDeadState(unitName)
    
                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(unitName, unitName)
    
                                if deathState.isCleaned == false then
                                    Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                                end
                            else
                                Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                            end
                        end
                    end
                else
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local unitName = unit:getName()

                            if self.cleanup_units[unitName] == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                            else
                                local deathState = Spearhead.internal.Persistence.UnitDeadState(unitName)
                                if deathState and deathState.isDead == true then
                                    Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
        
                                    if deathState.isCleaned == false then
                                        Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                                    end
                                else
                                    Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                                end
                            end
                        end
                    end
                end
            end
        end

        local spawnBlueUnits = function(self)

            for _, groupName in pairs(self.blue_groups) do
                if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                    Spearhead.DcsUtil.SpawnGroupTemplate(groupName)

                    local staticObject = StaticObject.getByName(groupName)
                    local unitName = staticObject:getName()
                    local deathState = Spearhead.internal.Persistence.UnitDeadState(unitName)

                    if deathState and deathState.isDead == true then
                        Spearhead.DcsUtil.DestroyUnit(unitName, unitName)

                        if deathState.isCleaned == false then
                            Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                        end
                    else
                        Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                    end
                else
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local unitName = unit:getName()
                            local deathState = Spearhead.internal.Persistence.UnitDeadState(unitName)
                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unitName)

                                if deathState.isCleaned == false then
                                    Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                                end
                            else
                                Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                            end
                        end
                    end
                end
            end
        end

        o.ActivateRedStage = function(self)
            if self.initialSide == 2 then
                self.airbase:setCoalition(1)
                self.airbase:autoCapture(false)
            end
            timer.scheduleFunction(spawnRedUnits, self, timer.getTime() + 3)
        end

        o.OnUnitLost = function (self, object)
            local unitName = object:getName()
            local pos = object:getPoint()
            local type = object:getDesc().typeName
            local position = object:getPosition()
            local heading = math.atan2(position.x.z, position.x.x)
            local country_id = object:getCountry()
            Spearhead.internal.Persistence.UnitKilled(unitName, pos, heading, type, country_id)
        end

        o.ActivateBlueStage = function(self)
            if self.initialSide == 2 then
                self.airbase:setCoalition(2)
            end

            cleanRedUnit(self)
            timer.scheduleFunction(spawnBlueUnits, self, timer.getTime() + 3)
        end

        return o
    end

end

if Spearhead == nil then Spearhead = {} end
if Spearhead.internal == nil then Spearhead.internal = {} end
Spearhead.internal.StageBase = StageBase



