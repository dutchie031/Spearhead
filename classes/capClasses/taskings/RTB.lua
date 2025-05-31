
---@class RTBTasking : Tasking
local RTB = {}


function RTB.getAsMission()
    --[[
        TODO: RTB MISSION
    ]]
end


---comment
---@param airdromeId number
---@param basePoint table { x, z, y } (y == alt)
---@param speed number the speed
---@return table task
function RTB.getAsTasking(airdromeId, basePoint, speed)
    
    if basePoint == nil then
        basePoint = Spearhead.Util.getAirbaseById(airdromeId):getPoint()
    end

    return {
        alt = basePoint.y,
        action = "Landing",
        alt_type = "BARO",
        speed = speed,
        ETA = 0,
        ETA_locked = false,
        x = basePoint.x,
        y = basePoint.z,
        speed_locked = true,
        formation_template = "",
        airdromeId = airdromeId,
        type = "Land",
        task = {
            id = "ComboTask",
            params = {
                tasks = {}
            }
        }
    }
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.capClasses then Spearhead.classes.capClasses = {} end
if not Spearhead.classes.capClasses.taskings then Spearhead.classes.capClasses.taskings = {} end
Spearhead.classes.capClasses.taskings.RTB = RTB