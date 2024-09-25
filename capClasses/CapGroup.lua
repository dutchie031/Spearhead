--[[

#### Why?
For Spearhead there's a lot of stages and states the mission can be in. <br/>
To make sure CAP units will be at the place where the mission maker expects them to be there's a naming convention that should help. <br/>
You as a mission maker will have full controll over where they are supposed to be, the script will take care of getting them there.
The CAP manager's goal is to provide dedicated aircraft scheduling that doesn't reset every stage reset.

Naming: CAP\_\<"A" | B"\>\<Config\>_\<Free form name\>
#### Config:
```
1 at x:               [<activeStage>]<capStage>
n and n  at x:        [<activeStage>,<activeStage>]<capStage>
n till n at x:        [<activeStage>-<activeStage>]<capStage>
n till n and n at x:  [<activeStage>-<activeStage>,<activeStage>]<capStage>
n till n at Active:   [<activeStage>-<activeStage>]A

divider: |

examples:

CAP_A[1-4,6]7|[5,7]8_SomeName => Will fly CAP at stage 7 when stages 1 through 4 and 6 are active and will fly CAP at 8 when 5 and 7 are active
CAP_A[2-5]5|[6]6_SomeName => Will fly CAP at stage 5 when stages 2 through 5 active and will fly CAP at 6 when 6 is active
CAP_A[1-5]A|[6]7_SomeName => Will fly CAP at the ACTIVE stage if Stages 1-5 are active. Basically following the active stages. Then when 6 is active it will fly in 7

CAP_B[1-5]A|[6]7_SomeName => Will fly BACKUP CAP for the active zones 1 through 5 and back up for 7 when 6 is active.

```

### How many? And how to add backups?

To fascilitate a nice flow of the mission and also make sure it doesn't oversaturate the zones with aircraft the script works with a Active/Backup system in the naming. <br/>
This really doesn't mean much per se once the mission runs, but most importantly is that the A units define how many groups there should be max in a zone at a time. <br/>
The B units will simply be used to fill that amount if the A units can't due to RTB, Death, Rearming etc. <br/>

#### Example

Take the units:
```
CAP_A[1-5]A_SomeName1
CAP_A[1-5]A_SomeName2
CAP_B[1-3,5]A_SomeName
```
`CAP_A...` units are primary units where the `CAP_B...` units are the backups. <br/>
In this case the CAP manager sees that for stages 1 through 5 this configuration requires 2 groups in the active zone. <br/>
If one of those 2 groups dies or is going back to base the B group will be used to top up the CAP units at that zone. <br/>
After scheduling the B units the A units that are back at base ready on the ramp will also not be scheduled until the CAP units that are active in the zone (inlcuding B units) drop below the required CAP unit (of 2 in this example)

In this example there is no Backup unit for zone 4. This might quiet down the CAP a little as the Active groups will have to rearm and refuel without there being any backup.

### What the cap manager does:
- Spawn aircraft on the ramp (or despawn when they are not needed anymore for culling)
- Send out aircraft based on where they are supposed to be
- Send Aircraft RTB after X time. <br/>
  RTB in this sense means back to its base of origin. Not the closest friendly base like DCS does.
- Simulates Rearming and then sending them out when needed.
- Delays aircraft for X amount of time before spawning and rearming after a groups demise.
- Aircraft are spawned on the ramp so OCA does have effect. (Be sure to also take a look at the Airbase and SAM spawning for defences)

### Future Ideas

- Aircraft rearm hubs with finite spawns on other airbases that get replenished by aircraft flying in.


]] --

local CapHelper = {}
do
    ---comment
    ---@param groupName string
    ---@return table?
    CapHelper.ParseGroupName = function(groupName)
        local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then
            local result = {}
            result.zonesConfig = {}

            -- CAP_[1-5]5|[6]6|[7]7_Sukhoi
            -- CAP_[1-5,7]A|[6]7_Sukhoi

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "A" then
                result.isBackup = false
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "B" then
                configPart = string.sub(configPart, 2, #configPart)
                result.isBackup = true
            elseif first == "[" then
                result.isBackup = false
            else
                table.insert(Spearhead.MissionEditingWarnings, "Could not parse the CAP config for group: " .. groupName)
                return nil
            end

            local subsplit = Spearhead.Util.split_string(configPart, "|")
            if subsplit then
                for key, value in pairs(subsplit) do
                    local keySplit = Spearhead.Util.split_string(value, "]")
                    local targetZone = keySplit[2]
                    local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                    local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                    for _, value in pairs(commaSeperated) do
                        local dashSeperated = Spearhead.Util.split_string(value, "-")
                        if Spearhead.Util.tableLength(dashSeperated) > 1 then
                            local from = tonumber(dashSeperated[1])
                            local till = tonumber(dashSeperated[2])

                            for i = from, till do
                                if targetZone == "A" then
                                    result.zonesConfig[tostring(i)] = tostring(i)
                                else
                                    result.zonesConfig[tostring(i)] = tostring(targetZone)
                                end
                            end
                        else
                            if targetZone == "A" then
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(dashSeperated[1])
                            else
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(targetZone)
                            end
                        end
                    end
                end
            end
            return result
        else
            table.insert(Spearhead.MissionEditingWarnings,
                "CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
    end
end

---comment
---@param input table { groupName, task, logger }
---@param time number
---@return nil
local function setTaskAsync(input, time)
    local task = input.task
    local groupName = input.groupName
    local group = Group.getByName(groupName)

    if task then
        group:getController():setTask(task)
        if input.logger ~= nil then
            input.logger:debug("task set succesfully to group " .. groupName)
        end
    end
    return nil
end

local CapGroup = {}

CapGroup.GroupState = {
    UNSPAWNED = 0,
    READYONRAMP = 1,
    INTRANSIT = 2,
    ONSTATION = 3,
    RTBINTEN = 4,
    RTB = 5,
    DEAD = 6,
    REARMING = 7
}

local function SetReadyOnRampAsync(self, time)
    self:SetState(CapGroup.GroupState.READYONRAMP)
end

---comment
---@param groupName string
---@param airbaseId number
---@param logger table logger dependency injection
---@param database table database  dependency injection
---@param capConfig table config dependency injection
---@return table? o
function CapGroup:new(groupName, airbaseId, logger, database, capConfig)
    local o = {}
    setmetatable(o, { __index = self })

    local RESPAWN_AFTER_TOUCHDOWN_SECONDS = 180

    -- initials
    o.groupName = groupName
    o.airbaseId = airbaseId
    o.logger = logger
    o.database = database

    local parsed = CapHelper.ParseGroupName(groupName)
    if parsed == nil then return nil end
    o.capZonesConfig = parsed.zonesConfig
    o.isBackup = parsed.isBackup

    --vars
    o.assignedStageName = nil
    o.assignedStageNumber = nil
    
    o.state = CapGroup.GroupState.UNSPAWNED
    o.aliveUnits = {}
    o.landedUnits = {}
    o.unitCount = 0
    o.onStationSince = 0
    o.currentCapTaskingDuration = 0
    o.markedForDespawn = false

    --config
    o.capConfig = {}

    if not capConfig then capConfig = {} end
    o.capConfig.maxDeviationRange = capConfig.maxDeviationRange
    o.capConfig.minSpeed = (capConfig.minSpeed or 400) * 0.514444
    o.capConfig.maxSpeed = (capConfig.maxSpeed or 500) * 0.514444
    o.capConfig.minAlt = (capConfig.minAlt or 8000) * 0.3048
    o.capConfig.maxAlt = (capConfig.maxAlt or 27000) * 0.3048
    o.capConfig.minDurationOnStation = capConfig.minDurationOnStation or 600
    o.capConfig.maxDurationOnstation = capConfig.maxDurationOnStation or 1800
    o.capConfig.rearmDelay = capConfig.rearmDelay or 300

    ---comment
    ---@param self table
    ---@param currentActive number
    ---@return table
    o.GetTargetZone = function (self, currentActive)
        return self.capZonesConfig[tostring(currentActive)]
    end

    o.SetState = function(self, state)
        self.state = state
        self:PublishUnitUpdatedEvent()
    end

    o.StartRearm = function(self)
        self:SpawnOnTheRamp()
        self:SetState(CapGroup.GroupState.REARMING)
        timer.scheduleFunction(SetReadyOnRampAsync, self, timer.getTime() + self.capConfig.rearmDelay - RESPAWN_AFTER_TOUCHDOWN_SECONDS)
    end

    o.SpawnOnTheRamp = function(self)
        self.markedForDespawn = false
        self.logger:debug("Spawning group " .. self.groupName)
        self.aliveUnits = {}
        self.landedUnits = {}
        self.onStationSince = 0

        local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName, nil, nil, true)
        if group then
            self.unitCount = group:getInitialSize()

            if self.state == CapGroup.GroupState.UNSPAWNED then
                self:SetState(CapGroup.GroupState.READYONRAMP)
            end

            for _, unit in pairs(group:getUnits()) do
                local name = unit:getName()
                self.aliveUnits[name] = true
                self.landedUnits[name] = false
            end
        end
    end

    o.Despawn = function(self)
        self.logger:debug("Despawning group " .. self.groupName)
        Spearhead.DcsUtil.DestroyGroup(self.groupName)
        self:SetState(CapGroup.GroupState.UNSPAWNED)
    end

    o.SendRTB = function(self)
        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            local speed = math.random(self.capConfig.minSpeed, self.capConfig.maxSpeed)
            local rtbTask, errormessage = Spearhead.RouteUtil.CreateRTBMission(self.groupName, self.airbaseId, speed)
            if rtbTask then
                timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
            else
                self.logger:error("No RTB task could be created for group: " .. self.groupName .. " due to " .. errormessage)
                if self.markedForDespawn == true then
                    self:Despawn()
                end
            end
        end
    end

    o.SendRTBAndDespawn = function(self)
        self.markedForDespawn = true
        o.SendRTB(self)
    end

    ---Starts and send this group to perform CAP at a stage
    ---@param self any
    ---@param stageZoneNumber string
    o.SendToStage = function(self, stageZoneNumber)
        if self.state == CapGroup.GroupState.DEAD or self.state == CapGroup.GroupState.RTB then
            return --Can't task a unit that's dead or RTB
        end

        local stageZoneName = self.database:getStageZoneByStageNumber(stageZoneNumber)
        self.assignedStageNumber = stageZoneNumber
        self.assignedStageName = stageZoneName
        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            local zone = Spearhead.DcsUtil.getZoneByName(stageZoneName)
            if zone then
                self.logger:debug("Sending group out " .. self.groupName)
                local controller = group:getController()
                local capPoints = database:getCapRouteInZone(stageZoneName, self.airbaseId) or { point1 = { x = zone.x, z = zone.z }, point2 = nil }

                local altitude = math.random(self.capConfig.minAlt, self.capConfig.maxAlt)
                local speed = math.random(self.capConfig.minSpeed, self.capConfig.maxSpeed)
                local attackHelos = false
                local deviationDistance = self.capConfig.maxDeviationRange
                local capTask
                if self.state == CapGroup.GroupState.ONRAMP or self.onStationSince == 0 then
                    controller:setCommand({
                        id = 'Start',
                        params = {}
                    })
                    local duration = math.random(self.capConfig.minDurationOnStation, self.capConfig
                    .maxDurationOnstation)
                    self.logger:debug("random schedule min: " ..
                    tostring(self.capConfig.minDurationOnStation or "nil") ..
                    " max: " .. tostring(self.capConfig.maxDurationOnstation or "nil") .. " actual " .. duration)
                    self.currentCapTaskingDuration = duration

                   
                    capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
                else
                    local duration = self.currentCapTaskingDuration - (timer.getTime() - o.onStationSince)
                    capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
                end

                if capTask then
                    timer.scheduleFunction(setTaskAsync,
                        { task = capTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
                end
                self:SetState(CapGroup.GroupState.INTRANSIT)
            end
        end
    end

    ---Starts and send a unit to another airbase
    ---@param self table
    ---@param airdomeId any
    o.SendToAirbase = function(self, airdomeId)
        self.airbaseId = airdomeId
        local speed = math.random(self.capConfig.minSpeed, self.capConfig.maxSpeed)
        local rtbTask = Spearhead.RouteUtil.CreateRTBMission(self.groupName, airdomeId, speed)
        local group = Group.getByName(self.groupName)
        local controller = group:getController()
        controller:setCommand({
            id = 'Start',
            params = {}
        })
        timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger },
            timer.getTime() + 5)
    end

    o.OnGroupRTB = function(self, groupName)
        if groupName == self.groupName then
            self.logger:debug("Setting group " ..
            groupName ..
            " to state RTB after a total of " ..
            timer.getTime() - self.onStationSince .. "s of the " .. self.currentCapTaskingDuration .. "s")
            self:SetState(CapGroup.GroupState.RTB)
        end
    end

    o.OnGroupRTBInTen = function(self, groupName)
        if groupName == self.groupName then
            self:SetState(CapGroup.GroupState.RTBINTEN)
        end
    end

    o.OnGroupOnStation = function(self, groupName)
        if groupName == self.groupName then
            self.onStationSince = timer.getTime()
            self.logger:debug("Setting group " .. groupName .. " to state Onstation")
            self:SetState(CapGroup.GroupState.ONSTATION)
        end
    end

    ---comment
    ---@param self table
    ---@param proActive boolean Will check all units in group for aliveness
    o.UpdateState = function(self, proActive)
        local landed = false
        local landedCount = 0
        for name, landedBool in pairs(self.landedUnits) do
            if landedBool == true then
                landedCount = landedCount + 1
                landed = true
            end
        end

        local deadCount = 0
        for name, isAlive in pairs(self.aliveUnits) do
            if isAlive == false then
                deadCount = deadCount + 1
            end
        end

        local function DelayedStartRearm(input, time)
            local capGroup = input.self
            capGroup:StartRearm()
        end

        if landedCount + deadCount == self.unitCount then
            if landed then
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + RESPAWN_AFTER_TOUCHDOWN_SECONDS)
                end
            else
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    local delay = self.capConfig.deathDelay - self.capConfig.rearmDelay + RESPAWN_AFTER_TOUCHDOWN_SECONDS
                    timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + delay)
                end
            end
        end
    end

    o.eventListeners = {}
    ---comment
    ---@param self table
    ---@param listener table object with  function OnGroupStateUpdated(capGroupTable)
    o.AddOnStateUpdatedListener = function(self, listener)
        if type(listener) ~= "table" then
            self.logger:error("Listener not of type table for AddOnStateUpdatedListener")
            return
        end

        if listener.OnGroupStateUpdated == nil then
            self.logger:error("Listener does not implement OnGroupStateUpdated")
            return
        end
        table.insert(self.eventListeners, listener)
    end

    o.PublishUnitUpdatedEvent = function(self)
        for _, callable in pairs(self.eventListeners) do
            local _, error = pcall(function()
                callable:OnGroupStateUpdated(self)
            end)
            if error then
                self.logger:error(error)
            end
        end
    end

    o.OnUnitLanded = function(self, initiatorUnit, airbase)
        if airbase then
            local airdomeId = airbase:getID()
            self.airbaseId = airdomeId
        end
        local name = initiatorUnit:getName()
        self.logger:debug("Received unit land event for unit " .. name .. " of group " .. self.groupName)

        self.landedUnits[name] = true
        self:UpdateState(false)
    end

    o.OnUnitLost = function(self, initiatorUnit)
        self.logger:debug("Received unit lost event for group " .. self.groupName)
        if initiatorUnit then
            self.aliveUnits[initiatorUnit:getName()] = false
        end
        self:UpdateState(false)
    end

    Spearhead.Events.addOnGroupRTBListener(o.groupName, o)
    Spearhead.Events.addOnGroupRTBInTenListener(o.groupName, o)
    Spearhead.Events.addOnGroupOnStationListener(o.groupName, o)
    local units = Group.getByName(groupName):getUnits()
    for key, unit in pairs(units) do
        Spearhead.Events.addOnUnitLandEventListener(unit:getName(), o)
        Spearhead.Events.addOnUnitLostEventListener(unit:getName(), o)
    end
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.CapGroup = CapGroup
