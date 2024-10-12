

local AttackGroup = {}

function AttackGroup:new(groupName, redAirbase, logger, database, casConfig)
    local o = {}
    setmetatable(o, { __index = self })

    o.groupName = groupName
    o.airbaseId = redAirbase.airbaseId
    o.parentManager = redAirbase
    o.logger = logger
    o.database = database
    o.casConfig = casConfig

    o.SendOut = function(self, escortGroupName)
        --[[
            TODO
        ]]
    end

    o.SendRTB = function(self)
        --[[
            TODO
        ]]
    end

end



if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.AttackGroup = AttackGroup
