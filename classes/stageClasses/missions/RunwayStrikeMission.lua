---@class RunwayStrikeMission : Mission
---@field runwayBombingTracker RunwayBombingTracker
---@field private _runway Runway
---@field private _runwayZone SpearheadTriggerZone
---@field private _airportName string
---@field private _runwaySections Array<RunwaySection>
---@field private _minKilosForDamage number
---@field private _repairInProgress boolean
local RunwayStrikeMission = {}

---@class RunwaySection
---@field center Vec2
---@field corners Array<Vec2> 
---@field kilosHit number
---@field repairGroups Array<string>
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

    self._airportName = airbaseName
    local missionBriefing = "Bomb runway " .. runway.Name .. " at " .. airbaseName .. "to delay the CAP effort"

    local success, error = Mission.newSuper(self, "noZone", runway.Name, "OCA", missionBriefing, "secondary", database, logger)

    self.runwayBombingTracker = runwayBombingTracker
    self._runway = runway
    self._runwayZone = self:RunwayToSpearheadZone(runway)
    self._repairInProgress = false
    self._minKilosForDamage = 100
    
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

    runwayBombingTracker:RegisterRunway(runway, self)

    return self
end

---activates the mission
function RunwayStrikeMission:SpawnActive()
    self._missionCommandsHelper:AddMissionToCommands(self)
    self:Draw()
    self:UpdateState()
end

---@return SpearheadTriggerZone
function RunwayStrikeMission:GetRunwayZone()
    return self._runwayZone
end

function RunwayStrikeMission:RunwayHit(impactPoint, explosiveMass)

    self._logger:debug("Runway hit: " .. self._airportName .. ":" .. self._runway.Name)
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
    local updateState = function(selfA, time)
        selfA:UpdateState()
    end

    timer.scheduleFunction(updateState, self, timer.getTime() + 5)

end

function RunwayStrikeMission:UpdateState()

    self._logger:debug("Updating state of runway strike mission " .. self._airportName .. ":" .. self._runway.Name)

    self:Draw()

    for _, section in pairs(self._runwaySections) do
        if section.kilosHit > self._minKilosForDamage then
            self:StartRepair()
            self._missionCommandsHelper:RemoveMissionToCommands(self)
            break
        end
    end
end

---@type DrawColor
local healthyAreaColor = { r=0, g=1, b=0, a=0.5 }
---@type DrawColor
local healthyAreaLineColor = { r=0, g=1, b=0, a=1 }
---@type DrawColor
local damagedAreaColor ={ r=1, g=165/255, b=0, a=0.5 }
---@type DrawColor
local damagedAreaLineColor = { r=1, g=165/255, b=0, a=1 }
---@type DrawColor
local destroyedAreaColor = { r=1, g=0, b=0, a=0.5 }
---@type DrawColor
local destroyedAreaLineColor = { r=1, g=0, b=0, a=1 }

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

            local color = { r=0, g=1, b=0, a=0.5 }

            runwaySection.drawID = Spearhead.DcsUtil.DrawZone(zone, color, color, 5)
        else
            Spearhead.DcsUtil.SetFillColor(runwaySection.drawID, fillColor)
            Spearhead.DcsUtil.SetLineColor(runwaySection.drawID, lineColor)
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
    self._logger:debug("Starting repair of runway strike mission " .. self._airportName .. ":" .. self._runway.Name)
    ---comment
    ---@param selfA any
    ---@return unknown
    local repairTask = function (selfA, time)
        local interval = selfA:DoRepairCycle()
        if interval == nil then return nil end
        return time + interval
    end
    
    timer.scheduleFunction(repairTask, self, timer.getTime() + 5)
end

function RunwayStrikeMission:DoRepairCycle()

    local interval = 5
    local repairPerSecond = 5

    self._logger:debug("Repair cycle for" .. self._airportName .. ":" .. self._runway.Name)

    local isHealed = true
    for _, section in pairs(self._runwaySections) do
        section.kilosHit = section.kilosHit - interval * repairPerSecond

        if section.kilosHit > self._minKilosForDamage * 0.1 then
            self:AddOrUpdateRepairStatics(section)
            isHealed = false
        else
            self:RemoveRepairStatics(section)
        end
    end

    self:Draw()

    if isHealed == true then
        self._repairInProgress = false
        self:FullRepairRunway()
        self._logger:debug("Repair complete for runway strike mission " .. self._airportName .. ":" .. self._runway.Name)
        return nil
    end

    return interval

end

---@class StaticSpawn 
---@field category string
---@field type string
---@field y number
---@field x number
---@field heading number


local counter = 1

---@type Array<Array<StaticSpawn>>
local repairStaticConfigs = {
    [1] = {
        [1] = {
            ["category"] = "Unarmed",
            ["type"] = "ZIL-135",
            ["y"] = -4,
            ["x"] = 10,
            ["heading"] = 6.2133721370998,
        },
        [2] = {
            ["category"] = "Unarmed",
            ["type"] = "Tigr_233036",
            ["y"] = 0,
            ["x"] = 10,
            ["heading"] = 6.2133721370998,
        },
        [3] = {
            ["category"] = "Unarmed",
            ["type"] = "Infantry AK ver3",
            ["y"] = 10,
            ["x"] = 7,
            ["heading"] = 4.4331363000656,
        },
        [4] = {
            ["category"] = "Unarmed",
            ["type"] = "Infantry AK ver3",
            ["y"] = 12,
            ["x"] = 1,
            ["heading"] = 4.4331363000656,
        },
        [5] = {
            ["category"] = "Unarmed",
            ["type"] = "Infantry AK ver3",
            ["y"] = -10,
            ["x"] = -2,
            ["heading"] = 4.1538836197465,
        },
        [6] = {
            ["category"] = "Unarmed",
            ["type"] = "CV_59_Large_Forklift",
            ["y"] = -11,
            ["x"] = 0,
            ["heading"] = 1.535889741755,
        },
        [7] = {
            ["category"] = "Unarmed",
            ["type"] = "ZiL-131 APA-80",
            ["y"] = 11,
            ["x"] = 5,
            ["heading"] = 0.62831853071796,
        },
        [8] = {
            ["category"] = "Unarmed",
            ["type"] = "CV_59_NS60",
            ["y"] = -4,
            ["x"] = -15,
            ["heading"] = 0.62831853071796,
        }
    },
    [2] = {
        [1] = {
            ["category"] = "Air Defence",
            ["type"] = "generator_5i57",
            ["y"] = 2.7889551542015,
            ["x"] = -4.7698247930386,
            ["heading"] = 4.0666171571468,
        },
        [2] = {
            ["category"] = "Infantry",
            ["type"] = "Infantry AK ver3",
            ["y"] = 3.639392285097,
            ["x"] = 1.4300755972836,
            ["heading"] = 5.0440015382636,
        },
        [3] = {
            ["category"] = "Infantry",
            ["type"] = "Infantry AK ver3",
            ["y"] = 3.5139072826724,
            ["x"] = -0.32671443666074,
            ["heading"] = 6.16101225954,
        },
        [4] = {
            ["category"] = "Unarmed",
            ["type"] = "ATMZ-5",
            ["y"] = -6.9556010010953,
            ["x"] = 3.007681753102,
            ["heading"] = 4.0666171571468,
        },
        [5] = {
            ["category"] = "Unarmed",
            ["type"] = "GAZ-66",
            ["y"] = 5.9304017026008,
            ["x"] = 0.80323129595153,
            ["heading"] = 6.2308254296198,
        }
    }
}

---@private
---@param section RunwaySection
function RunwayStrikeMission:AddOrUpdateRepairStatics(section)
    if Spearhead.Util.tableLength(section.repairGroups) > 0 then
        return
    end

    local location = { --Can randomise a little later
        x = section.center.x,
        y = section.center.y,
    }

    local repairGroup = Spearhead.Util.randomFromList(repairStaticConfigs)
    for _, repairStatic in pairs(repairGroup) do

        repairStatic.x = location.x + repairStatic.x
        repairStatic.y = location.y + repairStatic.y

        repairStatic.hidden = true
        repairStatic.name = "runway_repairunit_" .. counter
        counter = counter + 1
        coalition.addStaticObject(country.id.RUSSIA, repairStatic)
        table.insert(section.repairGroups, repairStatic.name)
    end
end


---@private 
---@param section RunwaySection
function RunwayStrikeMission:RemoveRepairStatics(section)
    if Spearhead.Util.tableLength(section.repairGroups) == 0 then
        return
    end

    for _, repairGroup in pairs(section.repairGroups) do
        local static = StaticObject.getByName(repairGroup)
        if static then
            static:destroy()
        end
    end

    section.repairGroups = {}
end

---@private 
function RunwayStrikeMission:FullRepairRunway()

    for _, section in pairs(self._runwaySections) do
        section.kilosHit = 0
        self:RemoveRepairStatics(section)
    end

    local minX = self._runwayZone.verts[1].x
    local minY = self._runwayZone.verts[1].y
    local maxX = self._runwayZone.verts[1].x
    local maxY = self._runwayZone.verts[1].y

    for _, vert in pairs(self._runwayZone.verts) do
        if vert.x < minX then
            minX = vert.x
        end
        if vert.x > maxX then
            maxX = vert.x
        end
        if vert.y < minY then
            minY = vert.y
        end
        if vert.y > maxY then
            maxY = vert.y
        end
    end

    ---@type Box
    local box = {
        id = world.VolumeType.BOX,
        params = {
            min = { x = minX, z = minY, y = 0 },
            max = { x = maxX, z = maxY, y = 10000 },
        }
    }
    world.removeJunk(box)
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

    if heading < 0 then
        heading = math.abs(heading)
    else
        heading = 0 - heading
    end

    local cosH = math.cos(heading)
    local sinH = math.sin(heading)

    for i = 0, numSections - 1 do
        local sectionCenterOffset = (i - (numSections / 2) + 0.5) * length

        ---@type Vec2
        local sectionCenter = {
            x = center.x + sectionCenterOffset * cosH,
            y = center.z + sectionCenterOffset * sinH
        }

        local halfWidth = width / 2
        local halfLength = length / 2

        ---@type Array<Vec2>
        local corners = {
            {
                x = sectionCenter.x + (-halfLength * cosH - halfWidth * sinH),
                y = sectionCenter.y + (-halfLength * sinH + halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (-halfLength * cosH + halfWidth * sinH),
                y = sectionCenter.y + (-halfLength * sinH - halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (halfLength * cosH + halfWidth * sinH),
                y = sectionCenter.y + (halfLength * sinH - halfWidth * cosH)
            },
            {
                x = sectionCenter.x + (halfLength * cosH - halfWidth * sinH),
                y = sectionCenter.y + (halfLength * sinH + halfWidth * cosH)
            }
        }

        ---@type RunwaySection
        local section = {
            center = sectionCenter,
            corners = corners,
            kilosHit = 0,
            repairGroups = {},
        }

        table.insert(sections, section)
    end

    return sections
end

---@private 
---@param runway Runway
---@return SpearheadTriggerZone
function RunwayStrikeMission:RunwayToSpearheadZone(runway)

    -- Calculate the 4 corner points of the runway based on heading, height, and width
    local radHeading = runway.course

    if radHeading < 0 then
        radHeading = math.abs(radHeading)
    else
        radHeading = 0 - radHeading
    end

    local cosH = math.cos(radHeading)
    local sinH = math.sin(radHeading)

    local halfWidth = runway.width / 2
    local halfHeight = runway.length / 2

    ---@type Array<Vec2>
    local corners = {
        {
            x = runway.position.x + (-halfHeight * cosH - halfWidth * sinH),
            y = runway.position.z + (-halfHeight * sinH + halfWidth * cosH)
        },
        {
            x = runway.position.x + (-halfHeight * cosH + halfWidth * sinH),
            y = runway.position.z + (-halfHeight * sinH - halfWidth * cosH)
        },
        {
            x = runway.position.x + (halfHeight * cosH + halfWidth * sinH),
            y = runway.position.z + (halfHeight * sinH - halfWidth * cosH)
        },
        {
            x = runway.position.x + (halfHeight * cosH - halfWidth * sinH),
            y = runway.position.z + (halfHeight * sinH + halfWidth * cosH)
        }
    }

    return {
        location = { x = runway.position.x, y = runway.position.z },
        radius = runway.width,
        name = runway.Name,
        verts = corners,
        zone_type = "Polygon",
    }
end



if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.missions then Spearhead.classes.stageClasses.missions = {} end
Spearhead.classes.stageClasses.missions.RunwayStrikeMission = RunwayStrikeMission