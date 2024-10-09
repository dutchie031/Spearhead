
SpearheadConfig = {

    CapConfig = {
        --quickly enable of disable the entire CAP Logic 
        --(you can also just rename all units to not be named "CAP_")
        enabled = true,
        
        --min ground speed for CAP aircraft during patrol
        -- unit: knots
        minSpeed = 400,

        --max speed for CAP aircraft during patrol
        -- unit: knots
        maxSpeed = 500,

        --minAlt for aircraft on patrol
        -- unit: feet
        minAlt = 18000,

        --maxAlt for aircraft on patrol
        -- unit: feet
        maxAlt = 28000,

        --Delay for aircraft from touchdown to off the chocks.
        -- unit: seconds
        rearmDelay = 600,

        --Delay for aircraft from death to takeoff.
        --When the seconds remaining is the same at the rearmDelay it will be spawned on the ramp and follow the rearm logic.
        -- !! Can not be lower than rearmDelay
        -- unit: seconds
        deathDelay = 1800,
    },

    StageConfig = {
        -- currently no configurable options
    }
}

