
--- Search and rescue missions are enhanced pick up missions. 
--- Basically they provide and interactive way of retrieving a downed pilot. 
--- A search area is defined. 


local SearchAndRescueMission = {}
do

    SearchAndRescueMission.SARType = {
        PILOT = 1,
        SF = 2
    }

    local pilotSearchRadius = 2000
    local counter = 500

    local spawnPilot = function(pos, country)
        counter = counter + 1

        local staticObj = {
            ["heading"] = 180,
            ["type"] = "Carrier LSO Personell 5",
            ["shape_name"] = "carrier_lso5_usa",
            ["name"] = "SAR_PILOT_" .. counter + 1,
            ["y"] = pos.z,
            ["x"] = pos.x,
            ["dead"] = false,
            ["hidden"] = true
        }

        local staticObject = coalition.addStaticObject(country, staticObj)

        local drawPos = {
            x = pos.x + math.random(-pilotSearchRadius, pilotSearchRadius),
            z = pos.y + math.random(-pilotSearchRadius, pilotSearchRadius)
        }

        trigger.action.circleToAll(-1, counter + 1, pos, pilotSearchRadius, {252/255, 240/255, 3/255, 1},  {252/255, 240/255, 3/255, 0.2}, 3)

        return staticObject, counter
    end

    
    function SearchAndRescueMission:new(sarManager, logger, missionCode, position, country, sarType)
        
        local o = {}
        setmetatable(o, { __index = self })

        o.sarManager =sarManager
        o.logger = logger
        o.missionCode = missionCode
        o.position = position
        o.sarType = sarType
        o.object = nil
        o.drawingId = nil

        if sarType == SearchAndRescueMission.SARType.PILOT then
            local object, drawingId = spawnPilot(position, country)
            o.drawingId = drawingId
            o.object = object
        end

        return o
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
Spearhead.classes.stageClasses.SearchAndRescueMission = SearchAndRescueMission