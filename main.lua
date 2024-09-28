--[[
    The Mission Manager creates a way to create missions in a stage like manner with missions without having to worry about monitoring and triggering of said missions.

    The Mission manager assumes players are BLUE and are fighting RED. (Which countries and spawns, that's up to you)

    Mission Naming TriggerZone: 
        Stage:              MISSIONSTAGE_<ordernumber>_Name
        Mission:            MISSION_<oneOf(DEAD, STRIKE, BAI, SAM)>_Name
        Random Mission:     RANDOMMISSION_<tasking>_<NAME>_<number>

    IMPORTANT NOTES
        - DO NOT put mission zones inside of mission zones.
        - DO NOT let stage zones overlap (or without there being anything indide of said overlap, this includes airbases)


    Stage Naming:   MISSIONSTAGE_<order[number]>_Name
        NOTE:   Multiple stages can have an order number.
                This gives you the opportunity to add multiple zones in a stage.
                All stages need to be completed for the next stage order to start.

    Player SPAWNS
        Airbases
            It is assumed all player spawns are Dynamic slots.
            These work relatively nicely nowadays and with a dynamic mission it can provide the best experience.
        FARPS
            Need to be in TriggerZone with name convention: "FARP_<name>"
            will be removed at start and activated inside of the active stage only, so be wary of where you place them.

    Mission Types and their logic:
        Random Missions: 
            To maximise replayability randomisation is directly supported. 
            There is 2 ways. First you can randomise the units inside of the mission zone the second way is to randomise the mission zone altogether.

            1. Randomising the units in the mission.
               You can use the "Chance" function for groups to spawn or not spawn groups inside of a mission zone.
               The framework will only take control over the units after the initial spawn and will therefore not spawn units that did not get spawned on initial creation.
               NOTE: This however gives the least predictable outcome and can easily lead to empty missions.
            
            2. Randomised mission zones
                The best way to randomise it to create X amount of trigger zones with the same mission and let the framework pick 1 on initialisation. 
                Naming convention: RANDOMMISSION_<tasking>_<NAME>_<number> (eg. RANDOMMISSION_BAI_BYRON_1 and RANDOMMISSION_BAI_BYRON_2)
                RANDOMMISSION: Recogniser
                tasking: the tasking just like any other mission
                NAME: Codename of the mission. (Use single word only for commands later on)
                number: can be any number. Only intention it to make it unique for the editor to not freak out.

                The framework will recognise that RANDOMMISSION_BAI_BYRON_1 and RANDOMMISSION_BAI_BYRON_2 compete against each other and will select a random one and add that to the stage. 
                After that a random mission will act just like any other mission. 

                TIP: If you want a mission that doesn't always spawn: You can do something like the following example: 
                    - RANDOMMISSION_BAI_BYRON_1 => The mission you want to spawn about 1 every 4 times with the units and description
                    - RANDOMMISSION_BAI_BYRON_2 => Empty trigger zone
                    - RANDOMMISSION_BAI_BYRON_3 => Empty trigger zone
                    - RANDOMMISSION_BAI_BYRON_4 => Empty trigger zone

        Special Types:
            SAM
                All SAM missions will be spawned during the stage, so there's no random pop-ups
                SAM missions will be have slightly different ways of briefing and will be shown in the overview of a stage as "known air defenses".
                SAMS however do not count towards the completion of the zone and will be despawned once all other missions are done.
                SAM missions of the NEXT 2 stages (by order) will also be spawned.
                This makes it so you can create defenses of airfields where CAP units are spawned and add long range defenses without having to make the stage huge.
                Eg. If MISSIONSTAGE_1_Name is active then all stages with numbers 2 and 3 will also have active SAMS.

                SAM vs DEAD
                Generally best practive: Use SAM missions for long range sams that need to be active for longer.
                Use DEAD for shorter range popup sams like moving SHORADS.


    AIRBASES
        Airbases have a special logic to them. This is to make sure that it's manageable which bases are used by friendly forces after pushing along.
        Capturable bases can be selected and units on airbases are managed.

        Logic is based on the starting coalition of the base.
            RED
                The base will be used for CAP of the enemy.
                On Capture the base will turn NEUTRAL.
                Units inside of the airport circle will despawn on the Stage completion.
            NEUTRAL
                Nothing will be done. It will not be used and units around the airport will not be specifically managed.
            BLUE
                Airbase will be set to "RED" on intialisation.
                All blue units will be despawned and red units spawned on activation of the zone.
                When the zone is captured by blue (by finishing the missions), all red units will be removed and all blue units inside it will spawn.

        Airbase Units
            All units inside of the circle of the airbase (shown in the me) and not in a mission zone will be regarded as a airbase unit and spawned when the airbase becomes active.

        Missions on airbases.
           Missions at airbases are perfectly possible. Any unit that is part of that mission will not be regarded as an "Airbase unit"

    AWACS
        ENEMY
            An enemy awacs will be spawned in the active stage + 2 unless it's disabled with Config.DisableAwacs.
            TODO: AWACS logic
        FRIENDLY
            Friendly AWACS will be spawned at the ACTIVE stage - 2. Which means that at the start there will be no awacs.
            There is one awacs spawned per stage with a delay of 15 minutes delay for respawn per default.
            If there is enough blue fighters a red fighter group will be spawned randomly to try and intercept the AWACS.
            A message will pop up and players are expected to defend it.
            This can be disabled wth Config.DisableAwacsInterceptTask


    SCRIPTERS
        This area of the documentation is for mission makers that want to hook into the framework from their own scripts. 
        This script will expose flags of it's state, but there are no public methods to alter the framework (at this time).

        FLAGS: 
          TODO: Expose flags for stage and other metrics
]] --

--[[
  TODOLIST:
  - FARPS and Airbases V
  - RANDOM missions
  
  - CAP Manager
  - Mission Activation
  - OPTIONAL Drawings

]] --

local dbLogger = Spearhead.LoggerTemplate:new("database", Spearhead.LoggerTemplate.LogLevelOptions.INFO)
local databaseManager = Spearhead.DB:new(dbLogger)

local capConfig = {
    maxDeviationRange = 32186, --20NM -- sets max deviation before flight starts pulling back,
    minSpeed = 400,
    maxSpeed = 500,
    minAlt = 18000,
    maxAlt = 28000,
    minDurationOnStation = 1800,
    maxDurationOnStation = 2700,
    rearmDelay = 600,
    deathDelay = 1800,
    logLevel  = Spearhead.LoggerTemplate.LogLevelOptions.INFO
}

local stageConfig = {
    logLevel = Spearhead.LoggerTemplate.LogLevelOptions.INFO
}

Spearhead.internal.GlobalCapManager.start(databaseManager, capConfig, stageConfig)
Spearhead.internal.GlobalStageManager.start(databaseManager)


Spearhead.Events.PublishStageNumberChanged(1)

Spearhead.LoadingDone()
--Check lines of code in directory per file: 
-- Get-ChildItem . -Include *.lua -Recurse | foreach {""+(Get-Content $_).Count + " => " + $_.name }; && GCI . -Include *.lua* -Recurse | foreach{(GC $_).Count} | measure-object -sum |  % Sum  
-- find . -name '*.lua' | xargs wc -l

