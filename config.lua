
SpearheadConfig = {

    StageConfig = {
        
        -- management of stages and its missions. 
        -- This is not related to CAP managers which will continue to work even if stage management is disabled
        enabled = true, -- default true

        --Will draw the active and the next stage 
        drawStages = true, -- default true

        --AutoStages will continue to the next stage automatically on completion of the missions within the stage. 
        -- If you want to make it so the next stage triggers only when you want to disable it here and manually implement the actions needed.
        --[[
            TODO: Add manual stage transition documentation
        ]]
        autoStages = true, --default true

        --Maximum missions per stage (includes all types of missions)
        maxMissionStage = 10
    },
    CasConfig = {

        -- Sets if there is a CAP unit unit required before a CAS unit is able to go out
        requireEscort = true, --default true

        --Delay for aircraft from touchdown to off the chocks.
        -- unit: seconds
        rearmDelay = 600, -- default 600

        --Delay for aircraft from death to takeoff.
        --When the seconds remaining is the same at the rearmDelay it will be spawned on the ramp and follow the rearm logic.
        -- !! Can not be lower than rearmDelay
        -- unit: seconds
        deathDelay = 1800, -- default 1800
    },
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

        -- while you can set CAP Groups to be of type "E" for dedicated escort, this setting will make it so that A and B groups (when ready on the ramp) will be used 
        -- when CasConfig.requireEscort is set to true (default: true) it no CAS units will be going out until there is escort available.
        -- once a unit is attached as escort it will not be applicable for a CAP duty until it has landed and rearmed
        useAvailableGroupsAsEscort = true

    },
    -- Bingo Fuel and Weapon Settings for each tasking 
    BingoSettings = {

        --- IMPORTANT NOTE!!
        --- As a general recommedation please do not set the units RTB values inside the ME. 
        --- While Spearhead tries to overwrite as little ME settings the RTB task in the ME is flawed to say the least. 
        --- "RTB ON FUEL" and "RTB ON NO WEAPONS" will have AI fly to a neutral base or to the closest red base. 
        --- Not to it's homeplate as expected. Spearhead will have them fly back to their original base, but cannot take control of AI if they are in the "RTB state"
        --- Generally AI will RTB way to late and crash due to no fuel anyway. So it's best to let Spearhead (or another script) manage this.
        --- With the BingoSettings Spearhead gives you options to customise the weapons and fuel settings for RTB SOPs

        --Defines the base profile used.
        baseProfile = "modern", -- oneOf( "modern", "ww2" )
        --The major difference between modern and ww2 settings are the existance of A/A missiles. 
        --Default settings will already reflect this.
        
        --- CustomProfiles are profiles overwriting the default profiles.
        --- Spearhead will do a lookup in order from big to small.
        --- Overwriting is on a per value basis. You can easily only overwrite 1 value and the rest will be kept default.
        --- You're free to overwrite any and all settings, but be aware that AI behaviour might significantly change.
        --- If for instance you do not give an aircraft heatseekers, but still set "NoHeatSeekers" to "true" an aircraft will RTB immediately.
        --- Possible keys: 
        ---     groupName   => Set specific settings for a specific groupName (groupNames are unchanged by spearhead)
        ---     typeName    => Set specific configuration for an aircraft type (use the type that is used by the scripting environment 
        ---                    check here:  https://github.com/Quaggles/dcs-lua-datamine/tree/d812189547cc01a757a59f29031cd29d6d4704c8/_G/db/Units/Planes/Plane)
        ---     taskingType => Already set based on baseProfile and general logical defaults. (No modern cap with guns only etc.)
        ---                    Can be overwritten. Types currently are: "CAP", "ESCORT", "CAS"
        CustomProfiles = {}

        ---Possible custom profile values (best to only set those settings you want to make 100% are set differently)
        --- ["key"] = Value 
        --- ["Fuel"] = 0.2 
        ---  
        --- A/A Settings
        --- ["NoRadarMissiles"] = false -- Send RTB when no radar missiles are remaining
        --- ["NoHeatSeekingMissiles"] = false -- Send RTB Wen no heatseekers remaining
        --- ["NoBullets"] = false
        --- 
        --- A/G Settings
        --- For now by default all need to evaluate true. So no HARMs, no Bombs, AND no rockets to RTB
        --- ["NoSeadMissiles"] = false -- no missiles like HARMs available
        --- ["NoRockets"] = false -- no rockets available 
        --- ["NoBombs"] = false -- no bombs available
    }
}

