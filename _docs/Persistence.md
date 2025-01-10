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

## Basic behavior

While playing the mission Spearhead is keeping track of all units killed. <br/>
These units are stored in memory internally and written to file. <br/>
This happens every 2 minutes AND during "onMissionStop" event to make sure the mission is as up to date as possible without having to call IO methods on each event.<br/>

## Misc units

## Missions

## Blue SAMs

## Airbases

## Warehouses

Currently warehouses are not implemented and therefore warehouses are not persisted. <br/>
When supply missions and logistics get implemented warehouses will be persisted as well. <br/>