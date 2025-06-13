
SpearheadConfig = {

    ---DEBUG LOGGING
    debugEnabled = false, -- default false

    CapConfig = {
        --quickly enable of disable the entire CAP Logic 
        --(you can also just rename all units to not be named "CAP_")
        enabled = true, -- default true
        
        --min ground speed for CAP aircraft during patrol
        -- unit: knots
        minSpeed = 400, -- default 400

        --max speed for CAP aircraft during patrol
        -- unit: knots
        maxSpeed = 500, -- default 500

        --minAlt for aircraft on patrol
        -- unit: feet
        minAlt = 18000, -- default 18000

        --maxAlt for aircraft on patrol
        -- unit: feet
        maxAlt = 28000, -- default 28000

        -- DELAYS.
        -- Delays work as follow.
        -- When an aircraft lands alive and well it will be rearmed and ready to go.
        -- When part of the flight died it will be repaired and then rearmed. (both delays)
        -- When the entire group dies it will first wait for the deathDelay, then it will be repaired and rearmed.
        -- while rearming: Spawned on the ramp.
        -- while repairing: Spawned on the ramp.
        -- while deathDelay no unit is spawned.

        --Delay for aircraft from touchdown to off the chocks.
        -- unit: seconds
        rearmDelay = 600, -- default 600

        -- Delay for aircraft that has died to be repaired before rearming starts.
        -- unit: seconds
        repairDelay = 600, -- default 600

        --Delay for aircraft before the repairing and rearming cycles begin.
        -- applied when the whole group dies.
        -- (see this as an additional bonus delay for destroying an entire group)
        -- unit: seconds
        deathDelay = 1800, -- default 1800
    },
    StageConfig = {
        
        -- management of stages and its missions. 
        -- This is not related to CAP managers which will continue to work even if stage management is disabled
        enabled = true, -- default true

        --Will draw the active and the next stage 
        drawStages = true, -- default true
        drawPreActivated = true, -- default true

        --Marking the last contact for any mission.
        --If a unit is killed the location will be permanently marked on the map until the mission is complete.
        --The location will continously update for the last killed unit.
        markLastContact = false, -- default false

        --AutoStages will continue to the next stage automatically on completion of the missions within the stage. 
        -- If you want to make it so the next stage triggers only when you want to disable it here and manually implement the actions needed.
        --[[
            TODO: Add manual stage transition documentation
        ]]
        autoStages = true, --default true

        --Maximum missions per stage (includes all types of missions)
        maxMissionStage = 10,

        --Stage starting number
        startingStage = 1,

        -- Amount of stages that are pre-activated on top of the current active stage.
        -- In Pre-activated the missions are not listed, but SAMs and Airbase groups are spawned.
        preactivateStage = 1, -- default 1
    },
    Persistence = {
        --- io and lfs cannot be sanitized in the MissionScripting.lua
        
        --- enables or disables the persistence logic in spearhead
        enabled = false,

        --- sets the directory where the persistence file is stored <br>
        --- if nil then lfs.writedir()/Data will be used. <br>
        --- which will Result in <Saved Games>/<DCS Saved Games Folder>/Data/
        directory = nil ,

        --- the filename of the persistence file. Should end with .json for convention, but any text extension should do.
        fileName = "Spearhead_Persistence.json"

    }
}

