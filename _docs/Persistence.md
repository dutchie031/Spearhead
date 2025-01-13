# Spearhead Persistence

Spearhead comes with a custom Persistence option. <br/>
It will even save burned out vehicles to give players a consistent battlefield even after the restart. <br/>

Most is pretty straight forward, however, some zones are somewhat special. <br/>
Underneath you'll see all special zones listed.

## Settings

To see the full config check: [Reference](./Reference.html#Configuration)

```lua
... Rest of config
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
... Rest of config

```

## Feedback

Since this feature is still very much in development, please let any issues know as soon as possible and as consice as possible so a fix can be made quickly. 

## Basic behavior

While playing the mission Spearhead is keeping track of all units killed. <br/>
These units are stored in memory internally and written to file. <br/>
This happens every 2 minutes AND during "onMissionStop" event to make sure the mission is as up to date as possible without having to call IO methods on each event.<br/>

## Misc units

Miscelaneous units will follow basic behaviour. <br/>
These are units that are part of a stage, but are not in a mission or airbase. <br/>
These units will be replaced by a static "DEAD" unit after a mission restart at the location it was killed. <br/>
Due to blue units spawning afterwards it's generally best to not have these units move through or over areas where BLUESAMS and Airbase units will spawn after a stage completion.

## Missions

Missions follow the same logic as Misc Units. <br/>

## Blue SAMs

For Blue SAMs, due to placements easily overlapping between red and blue units within a BLUESAM trigger zone red units that overlap with blue units will be deleted. 
<br/>
This will ensure that the blue units are placed as needed. <br/>


## Airbases

Airbase units will also be checked for overlap. As the blue units will be spawned after the RED unit. <br/>
Units that were alive when the stage was completed will be removed. Units that died will have corpses spawned. <br/>

## Warehouses

Currently warehouses are not implemented and therefore warehouses are not persisted. <br/>
When supply missions and logistics get implemented warehouses will be persisted as well. <br/>