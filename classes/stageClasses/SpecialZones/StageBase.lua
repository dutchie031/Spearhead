


local StageBase = {}

do
    ---@class StageBase 
    ---@field ActivateRedStage fun(self:StageBase) Activate the red state
    ---@field ActivateBlueStage fun(self:StageBase) Activate the blue stage after capture
    ---@field _database Database
    ---@field _logger Logger
    ---@field _red_groups Array<string>
    ---@field _blue_groups Array<string>
    ---@field _cleanup_units table<string, boolean>
    ---@field _airbase table
    ---@field _initialSide number?


    ---comment
    ---@param databaseManager table
    ---@param logger table
    ---@param airbaseId integer
    ---@return StageBase
    function StageBase:New(databaseManager, logger, airbaseId)

        local o = {}
        setmetatable(o, { __index = self })
    
        o._database = databaseManager
        o._logger = logger

        o._red_groups = {}
        o._blue_groups = {}
        o._cleanup_units = {}

        o._airbase = Spearhead.DcsUtil.getAirbaseById(airbaseId)
        o._initialSide = Spearhead.DcsUtil.getStartingCoalition(airbaseId)

        do --init
            local redUnitsPos = {}
            local blueUnitsPos = {}

            do -- fill tables
              local redGroups = databaseManager:getRedGroupsAtAirbase(airbaseId)
              if redGroups then
                for _, groupName in pairs(redGroups) do
                    
                    table.insert(o._red_groups, groupName)

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
                    
                    table.insert(o._blue_groups, groupName)

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
                            o._cleanup_units[redUnitName] = true
                        end
                    end
                end
            end
        end

        ---comment
        ---@param self StageBase    
        local spawnRedUnits = function(self)
            for _, groupName in pairs(self._red_groups) do
                local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)

                if group then
                    for _, unit in pairs(group:getUnits()) do
                        local unitName = unit:getName()
                        local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(groupName, unit:getName())
                        else
                            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
                        end
                    end
                end
            end
        end

        ---comment
        ---@param self StageBase
        local cleanRedUnit = function(self)
            for _, groupName in pairs(self._red_groups) do
                if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                    Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    local staticObject = StaticObject.getByName(groupName)

                    if staticObject then
                        if self._cleanup_units[groupName] then
                            staticObject:destroy()
                        else
                            local unitName = staticObject:getName()
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
    
                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(unitName, unitName)
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
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

                            if self._cleanup_units[unitName] == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                            else
                                local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                                if deathState and deathState.isDead == true then
                                    Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                                    Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
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
                    local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)

                    if deathState and deathState.isDead == true then
                        Spearhead.DcsUtil.DestroyUnit(unitName, unitName)
                        Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                    else
                        Spearhead.Events.addOnUnitLostEventListener(unitName, self)
                    end
                else
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(groupName)
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local unitName = unit:getName()
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(groupName, unitName)
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
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
            Spearhead.classes.persistence.Persistence.UnitKilled(unitName, pos, heading, type, country_id)
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
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.StageBase = StageBase



