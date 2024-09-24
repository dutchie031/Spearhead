
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

## Stage

A stage is a logical part of a mission. It's isn't anything special per se, but everything revolves around stages in Spearhead. <br/>
Everything is tied to at a stage. <br/>
A

### Completion

### On Completion


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