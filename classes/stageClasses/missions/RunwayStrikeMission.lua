---@class RunwayStrikeMission : Mission
---@field runwayBombingTracker RunwayBombingTracker
---@field private _runway Runway
---@field private _runwaySections Array<RunwaySection>
---@field private _minKilosForDamage number
---@field private _repairInProgress boolean
local RunwayStrikeMission = {}

---@class RunwaySection
---@field corners Array<Vec2> 
---@field kilosHit number
---@field craters Queue
---@field drawID number?


---@param runway Runway
---@param database Database
---@param logger Logger
---@param runwayBombingTracker RunwayBombingTracker
---@return RunwayStrikeMission?
function RunwayStrikeMission.new(runway, airbaseName, database, logger, runwayBombingTracker)
    
    local Mission = Spearhead.classes.stageClasses.missions.baseMissions.Mission
    RunwayStrikeMission.__index = RunwayStrikeMission
    setmetatable(RunwayStrikeMission, Mission)
    local self = setmetatable({}, RunwayStrikeMission)

    local missionBriefing = "Bomb runway " .. runway.Name .. " at " .. airbaseName .. "to delay the CAP effort"

    local success, error = Mission.newSuper(self, "noZone", runway.Name, "OCA", missionBriefing, "secondary", database, logger)

    self.runwayBombingTracker = runwayBombingTracker
    self._runway = runway
    self._repairInProgress = false
    self._minKilosForDamage = 500
    local sections = self:ToSections(runway, 5)
    --[[
        +-----------+-----------+-----------+-----------+-----------+
        | Section 1 | Section 2 | Section 3 | Section 4 | Section 5 |
        +-----------+-----------+-----------+-----------+-----------+
    ]]

    self._runwaySections = {
        sections[2],
        sections[3],
        sections[4],
    } --only take 2, 3 and 4 cause those are the most imporant parts of the runway

    if not success then
        logger:error("Failed to create RunwayBombingMission " .. runway.Name .. " => " .. error)
        return nil
    end

    return self
end

---activates the mission
function RunwayStrikeMission:SpawnActive()
    self._missionCommandsHelper:AddMissionToCommands(self)
end

function RunwayStrikeMission:RunwayHit(impactPoint, explosiveMass)

    for _, section in pairs(self._runwaySections) do
        
        local zone = self:SectionToSpearheadZone(section)
        if Spearhead.Util.is3dPointInZone({ x = impactPoint.x, z = impactPoint.y, y = 0 }, zone) then
            if section.kilosHit == nil then
                section.kilosHit = 0
            end

            section.kilosHit = section.kilosHit + explosiveMass
        end
    end

    ---@param selfA RunwayStrikeMission
    local updateState = function(selfA)
        
    end

    timer.scheduleFunction(updateState, self, timer.getTime() + 5)

end

function RunwayStrikeMission:UpdateState()
    self:Draw()

    for _, section in pairs(self._runwaySections) do
        if section.kilosHit > self._minKilosForDamage then
            RunwayStrikeMission:StartRepair()
            break
        end
    end
end

local healthyAreaColor = { 0,1,0, 0.5 }
local healthyAreaLineColor = { 0,1,0, 1 }
local damagedAreaColor = { 1, 165/255,0, 1 }
local damagedAreaLineColor = { 1, 165/255,0, 1 }
local destroyedAreaColor = { 1,0,0, 0.5 }
local destroyedAreaLineColor = { 1,0,0, 1 }

---@private
function RunwayStrikeMission:Draw()
    ---comment
    ---@param runwaySection RunwaySection
    local function drawSection(runwaySection)
        local lineColor = healthyAreaLineColor
        local fillColor = healthyAreaColor

        local orangeDamage = self._minKilosForDamage - 100
        if orangeDamage < 0 then orangeDamage = self._minKilosForDamage * 0.8 end

        if runwaySection.kilosHit > self._minKilosForDamage then
            lineColor = destroyedAreaLineColor
            fillColor = destroyedAreaColor
        elseif runwaySection.kilosHit > orangeDamage then
            lineColor = damagedAreaLineColor
            fillColor = damagedAreaColor
        end

        if runwaySection.drawID == nil then
            local zone = self:SectionToSpearheadZone(runwaySection)

            runwaySection.drawID = Spearhead.DcsUtil.DrawZone(zone, lineColor, fillColor, 5)
        else
            trigger.action.setMarkupColor(runwaySection.drawID, lineColor)
            trigger.action.setMarkupColorFill(runwaySection.drawID, fillColor)
        end

    end

    for _, section in pairs(self._runwaySections) do
        drawSection(section)
    end
end

---@private
---@param section RunwaySection
---@return SpearheadTriggerZone
function RunwayStrikeMission:SectionToSpearheadZone(section)
    return {
        location = { x = self._runway.position.x, y = self._runway.position.z },
        radius = self._runway.width,
        name = self._runway.Name,
        verts = section.corners,
        zone_type = "Polygon",
    }
end

---@

function RunwayStrikeMission:StartRepair()
    if self._repairInProgress == true then return end

    self._repairInProgress = true

    ---comment
    ---@param selfA any
    ---@return unknown
    local repairTask = function (selfA)
        return selfA:DoRepairCycle()
    end
    timer.scheduleFunction(repairTask, self, timer.getTime() + 5)
end

function RunwayStrikeMission:DoRepairCycle()



end

---@private
function RunwayStrikeMission:UpdateRepairStatics()

end



---@private
---@param runway Runway
---@return Array<RunwaySection>
function RunwayStrikeMission:ToSections(runway, numSections)

    local sections = {}
    local center = runway.position
    local heading = runway.course
    local width = runway.width
    local length = runway.length / numSections

    local radHeading = math.rad(heading)
    local cosH = math.cos(radHeading)
    local sinH = math.sin(radHeading)

    for i = 0, numSections - 1 do
        local sectionCenterOffset = (i - (numSections / 2) + 0.5) * length

        local sectionCenter = {
            x = center.x + sectionCenterOffset * cosH,
            z = center.z + sectionCenterOffset * sinH
        }

        local halfWidth = width / 2
        local halfLength = length / 2

        local corners = {
            {
                x = sectionCenter.x + (-halfLength * cosH - halfWidth * sinH),
                z = sectionCenter.z + (-halfLength * sinH + halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (-halfLength * cosH + halfWidth * sinH),
                z = sectionCenter.z + (-halfLength * sinH - halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (halfLength * cosH + halfWidth * sinH),
                z = sectionCenter.z + (halfLength * sinH - halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (halfLength * cosH - halfWidth * sinH),
                z = sectionCenter.z + (halfLength * sinH + halfWidth * cosH)
            }
        }

        ---@type RunwaySection
        local section = {
            corners = corners,
            kilosHit = 0,
            craterLocations = Spearhead._baseClasses.Queue.new(),
        }

        table.insert(sections, section)
    end

    return sections
end


