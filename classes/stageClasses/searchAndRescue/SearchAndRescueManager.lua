

local SearchAndRescueManager = {}
do

    --[[
        {
            pos,

        }
    ]]--

    local missions = {}

    function SearchAndRescueManager:createAndStart(logger)

        local o = {}
        setmetatable(o, { __index = self })

        o.OnPlayerEntersUnit = function(self, unit)

        end

        o.OnUnitEjected = function(self, unit, target)

        end

        return o
    end

end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
Spearhead.classes.stageClasses.SearchAndRescueManager = SearchAndRescueManager