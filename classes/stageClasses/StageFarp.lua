

local StageFarp = {}
do
    

    function StageFarp:new(database, logger, farpZoneName)

        local o = {}
        setmetatable(o, { __index = self })

        o.db = database
        o.logger = logger

        o.red_groups = {}
        o.blue_groups = {}
        o.cleanup_units = {}
        o.spawn_pads = {}

        do --init
            
            local redUnitsPos = {}
            local blueUnitsPos = {}

            do -- fill tables
                local groups = database:getGroupsInFarpZone(farpZoneName)
                for _, groupName in pairs(groups) do

                    if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                        local staticObject = StaticObject.getByName(groupName)
                        if staticObject then
                            if staticObject:getCoalition() == 1 then
                                table.insert(o.red_groups, groupName)
                                redUnitsPos[groupName] = staticObject:getPoint()
                            elseif staticObject:getCoalition() == 2 then
                                table.insert(o.blue_groups, groupName)
                                blueUnitsPos[groupName] = staticObject:getPoint()
                            end
                        end
                    else
                        local group = Group.getByName(groupName)
                        if group then
                            if group:getCoalition() == 1 then
                            
                                table.insert(o.red_groups, groupName)

                                for _, unit in pairs(group:getUnits()) do
                                    redUnitsPos[unit:getName()] = unit:getPos()
                                end
                            elseif group:getCoalition() == 2 then
                                table.insert(o.blue_groups, groupName)

                                for _, unit in pairs(group:getUnits()) do
                                    blueUnitsPos[unit:getName()] = unit:getPos()
                                end
                            end
                        end
                    end
                    Spearhead.DcsUtil.DestroyGroup(groupName)
                end
            end
            
            do -- mark cleanable
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

        o.ActivateRedStage = function(self)

        end

        o.ActivateBlueStage = function(self)
            
        end

        return o
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.internal == nil then Spearhead.internal = {} end
Spearhead.internal.StageFarp = StageFarp