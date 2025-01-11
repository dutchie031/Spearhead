

local SearchAndRescueManager = {}
do

    --[[
        {
            pos,

        }
    ]]--

    local missions = {}
    local rescueUnits = {}

    function SearchAndRescueManager:createAndStart(database, logger)

        local o = {}
        setmetatable(o, { __index = self })

        o.logger = logger
        o.database = database

        o.OnPlayerEntersUnit = function(self, unit)
            local desc = unit:getDesc()
            if desc.attributes["Transport Helicopter"] == true or (desc.attributes["Transports" and "Helicopters"]) then
                rescueUnits[unit:getName()] = unit
            end
        end

        o.OnEjectedUnitLanded = function(self, unit)

            self.logger:info(Spearhead.Util.toString(unit:getDesc()))
            local pos = unit:getPoint()
            local missionId = self.database:GetNewMissionCode()
            local type = Spearhead.classes.stageClasses.SearchAndRescueMission.SARType.PILOT
            unit:destroy()
            local mission = Spearhead.classes.stageClasses.SearchAndRescueMission:new(self, self.logger, missionId, pos, unit:getCountry(), type)

            missions[tostring(missionId)] = mission
        end

        Spearhead.Events.AddEjectedUnitLandedListener(o)

        local updateMissionMenu = function()

        end

        return o
    end

end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
Spearhead.classes.stageClasses.SearchAndRescueManager = SearchAndRescueManager