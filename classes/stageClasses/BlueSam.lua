

local BlueSam = {}

do
    function BlueSam:new(database, logger, zoneName)

        local o = {}
        setmetatable(o, { __index = self})

        o.database = database
        o.logger = logger
        o.zoneName = zoneName

        o.redGroups = {}
        o.blueGroups = {}
        o.cleanupUnits = {}

        do
            local groups = database:getBlueSamGroupsInZone(zoneName)

            local blueUnitsPos = {}
            local redUnitsPos = {}

            for _, groupName in pairs(groups) do
                    if Spearhead.DcsUtil.IsGroupStatic(groupName) then
                        local staticObject = StaticObject.getByName(groupName)

                        if staticObject:getCoalition() == 1 then
                            table.insert(o.redGroups, groupName)
                            redUnitsPos[staticObject:getName()] = staticObject:getPoint()
                        end

                        if staticObject:getCoalition() == 2 then
                            table.insert(o.blueGroups, groupName)
                            blueUnitsPos[staticObject:getName()] = staticObject:getPoint()
                        end
                    else
                        local group = Group.getByName(groupName)
                        if group:getCoalition() == 1 then
                            table.insert(o.redGroups, groupName)
                        elseif group:getCoalition() == 2 then
                            table.insert(o.blueGroups, groupName)
                        end

                        for _, unit in pairs(group:getUnits()) do
                            if group:getCoalition() == 1 then
                                table.insert(blueUnitsPos, unit:getPoint())
                            elseif group:getCoalition() == 2 then
                                table.insert(redUnitsPos, unit:getPoint())
                            end
                        end
                    end
                    Spearhead.DcsUtil.DestroyGroup(groupName)
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

        o.Activate = function(self)
            for unitName, needsCleanup in pairs(self.cleanupUnits) do
                if needsCleanup == true then
                    Spearhead.DcsUtil.DestroyUnit(unitName)
                else
                    local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
                    if deathState and deathState.isDead == true then
                        Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                    end
                end
            end

            for _, blueGroup in pairs(self.blueGroups) do
                if Spearhead.DcsUtil.IsGroupStatic(blueGroup) then
                    Spearhead.DcsUtil.SpawnGroupTemplate(blueGroup)
                    local staticObject = StaticObject.getByName(blueGroup)

                    if staticObject then
                        local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(blueGroup)
                        if deathState and deathState.isDead == true then
                            Spearhead.DcsUtil.DestroyUnit(blueGroup)
                            Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, blueGroup, deathState.type, deathState.pos, deathState.heading)
                        end
                    end
                else
                    local group = Spearhead.DcsUtil.SpawnGroupTemplate(blueGroup)
                    if group then
                        for _, unit in pairs(group:getUnits()) do
                            local unitName = unit:getName()
                            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)

                            if deathState and deathState.isDead == true then
                                Spearhead.DcsUtil.DestroyUnit(unitName)
                                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
                            end
                        end
                    end
                end
            end
        end

        return o
    end
end
if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
Spearhead.classes.stageClasses.BlueSam = BlueSam
