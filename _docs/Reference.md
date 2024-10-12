
# Spearhead Reference

## For the Story tellers

Spearhead. A framework created for the mission maker. <br/>
For those who do want to create a mission with a story and progress, but do not want to get into scripting. Creating an engaging mission can be an incredible feat. First think of the mission, the submission, the placement, the time. Once the concept is done you'll need to place all the objects into the editor. Not too many, but also not too little. Then comes the scripts to make it feel engaging and organic. The latter is probably the biggest hurdle. 

Spearhead is created to try and make this entire process a lot easier.
It keeps track of completed missions, moves the stages forward once all mission are complete. <br/> Manages CAP in an easy to setup way (no scripting required) and gives a lot of possibilities to the mission maker. <br/>
The goal is for the mission maker to focus on the story and the detailed missions, without having to worry about all the triggers and mission management the scripts normally take care off.

## Get Started

This page will give you a detailed overview of all options, moving parts and logic that goes into Spearhead. <br/>
If you however want to go right to the Get Started guide click here: [here](./GetStarted.html#completion) <br/>
You can always come back later here. <br/>
The Get Started guide will not show all details and reasoning. <br/>

## Release Notes

<details>
<summary>01-10-2024 Initial Version </summary> 
The initial version with basic functionality
</details>

## Feature / TODO list

- [ ] CAP Manager
    - [x] RTB flow. Flying out before primary flies back. 
    - [ ] Out of Missile flow 
- [ ] Stage
    - [ ] Pre Activate
      - [x] All SAM Sites
      - [x] All Red airbase units
      - [ ] OCA Missions
    - [ ] Activate
      - [ ] Activate all DEAD sites. (No surprise pop ups)
      - [ ] Activate other random mission till 10 max
    - [ ] Completion Logic
      - [ ] ?? Custom Conditions ??
      - [ ] ?? Airbases as final mission ??
      - [ ] Required Mission types
- [ ] Missions
  - [x] BAI
  - [x] DEAD
  - [x] STRIKE
  - [ ] INTERCEPT
  - [ ] LOGISTIC
  - [ ] EXTRACTION | MEDEVAC
  - [ ] More?

- [ ] Warehouses
  - [ ] Logistics [OPTIONAL]
  - [ ] 

- [ ] Team creation
- [ ] Airbases
- [ ] Farps 
- [ ] Carrier/Fleet routes
    - [ ] Fleet tracks
- [ ] Persistance


## Configuration

Spearhead will always try to be as configurable as possible. <br/>
Underneath you can see all configuration values. Be aware there are nested tables. <br/>
The values are the default values in case no configuration was found. <br/>
You can also choose to programatically overwrite only the parts that you want, but be aware of `nil` references and order of files. 

Overwrite the values in your own script (before spearhead runs) or <a download="spearheadConfig.lua" href="./spearheadConfig.lua" target="_blank" rel="noopener noreferrer">Download Config File</a> to edit

```lua
  ##!config!##
```

## Stage

A stage is a logical part of a mission. It's isn't anything special per se, but everything revolves around stages in Spearhead. <br/>
Everything is tied to at a stage. <br/>



## Mission

A mission is a completable objective with a state and a continuous check to see if itself is completed. <br/>
The delay between checks is quite big, but it also is checked on unit deaths and other events.


### Placement
The placement of MISSION trigger zones can be anywhere. <br/>
The order of unit detection is `CAP` > `MISSION` > `AIRBASE` > `STAGE` <br/>
This means that if a unit has a name that starts with `"CAP_"` it will not be included in a mission. <br/>
But all other units in a `MISSION` trigger zone will be managed as part of that mission.

Units inside a `MISSION` do not have to stay within the triggerzone. <br/>
They just need to be inside the zone at the start of the mission. <br/>
You can for example let a `BAI` mission drive back and forth between airbases. The `MISSIONZONE` only needs to be around the units that are part of the objective, not the waypoints.

### Naming
`MISSION_<type>_<name>` <br/>
`RANDOMMISSION_<type>_<name>_<index>` (Read RANDOMISATION below)

With: <br/>
`name` = A name that is easy to remember and type. Like a codename. Exmaples: BYRON, PLUKE, etc. <br/>
`type` = any of the below described types. Special types are marked with an *

TIP: You can click on the type to get more details

<details> 
<summary>SAM*</summary>
&emsp; SAM Sites are managed a little different. SAM Sites can be used to guide players and to protect airfields. <br/>
&emsp; In the future when deepstrike missions might come into scope these SAM sites will also be more important. <br/>
&emsp; SAM sites will be activated when a zone is "Pre-Active". <br/>
&emsp; A stage is "Pre-Active" when there is a CAP base active, or there is other things to do that would need the SAM site to be live (OCA, DEEPSTRIKE, EXTRACTION \<= all feature development)<br/>
&emsp; If you want a SAM site to become active ONLY when the stage is fully active, then `DEAD` is the type for you!

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 

</details>

<details> 
<summary>DEAD</summary>

&emsp; DEAD missions will be spawned on activation of the stage. <br/>
&emsp; ALL DEAD missions will be activated right at the start of a stage. <br/>
&emsp; This might be against the "randomisation" feel, but it is to make sure mission don't get activated randomly and players get ambushed by a random spawn. <br/>

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 

</details>

<details> 
<summary>BAI</summary>
</details>

<details> 
<summary>STRIKE</summary>
&emsp; STRIKE missions will be activated randomly until all of them are completed. <br/>
&emsp; A strike mission can be placed anywhere, even on airbases

&emsp; <u>Completion logic</u> <br/>
&emsp; TODO: documentation: Completion logic 

</details>

### TGT targets

There is 2 ways a mission can complete which depends on the precense 

### Randomisation

You can randomize missions. <br/>
Spearhead will pick up all mission zones that start with `"RANDOMMISSION_"` <br/>
Then it will combine each `RANDOMMISSION` in a zone with the same `<name>` and pick a random one. <br/>
It will always pick 1 and only 1.

This means you have some options for randomisation. <br/>
For example, if you have 1 missionzone with name `RANDOMMISSION_SAM_PLUKE_1` that is filled with an SA-2 and another zone with `RANDOMMISSION_SAM_PLUKE_2` filled with an SA-3 then some runs of the mission it will spawn an SA-3 and sometimes spawn an SA-3. (works for any mission type)

What you can also do is add empty `RANDOMMISSION_` zones next to the filled `RANDOMMISSION_` zone. 
For example. You have a `RANDOMMISSION_DEAD_BYRON_1` filled with an SA-19 driving around and 2 more `RANDOMMISSION_DEAD_BYRON_<2 & 3>` zones then it will have a 33% chance of being spawned.
If a zone is empty it will not be briefed, activated or count towards completion of the `STAGE`


### CAP 


#### CAP Config: 

--[[
  TODO: CAP CONFIG
]]

Naming: CAP\_\<"A" | B"\>\<Config\>_\<Free form name\>
##### CAP Group Config:
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

#### How many? And how to add backups?

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

#### What the cap manager does:
- Spawn aircraft on the ramp (or despawn when they are not needed anymore for culling)
- Send out aircraft based on where they are supposed to be
- Send Aircraft RTB after X time. <br/>
  RTB in this sense means back to its base of origin. Not the closest friendly base like DCS does.
- Simulates Rearming and then sending them out when needed.
- Delays aircraft for X amount of time before spawning and rearming after a groups demise.
- Aircraft are spawned on the ramp so OCA does have effect. (Be sure to also take a look at the Airbase and SAM spawning for defences)

#### Future Ideas

- Aircraft rearm hubs with finite spawns on other airbases that get replenished by aircraft flying in.