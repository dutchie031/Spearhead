
SpearheadConfig = {

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

        --Delay for aircraft from touchdown to off the chocks.
        -- unit: seconds
        rearmDelay = 600, -- default 600

        --Delay for aircraft from death to takeoff.
        --When the seconds remaining is the same at the rearmDelay it will be spawned on the ramp and follow the rearm logic.
        -- !! Can not be lower than rearmDelay
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

        ---DEBUG logging. Consider keeping this disabled
        debugEnabled = false
    },
    Persistence = {
        --- io and lfs cannot be sanitized in the MissionScripting.lua
        
        --- enables or disables the persistence logic in spearhead
        enabled = false,

        --- sets the directory where the persistence file is stored
        --- if nil then lfs.writedir() will be used. 
        --- which will 
        directory = nil ,

        --- the filename of the persistence file. Should end with .json for convention, but any text extension should do.
        fileName = "Spearhead_Persistence.json"

    }
}

