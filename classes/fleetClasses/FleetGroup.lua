



local FleetGroup = {}
function FleetGroup:new(fleetGroupName, database)

    local o  = {}
    setmetatable(o, { __index = self })

    



    o.OnStageNumberChanged = function(self, number)

    end

    Spearhead.Events.AddStageNumberChangedListener(o)
    return o
end





if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.FleetGroup = FleetGroup