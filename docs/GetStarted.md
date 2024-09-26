
# Spearhead


## Get Started

This guide is to get you started building your first Spearhead mission. <br/>
Spearhead was created to enable the mission maker to worry as little about the running, timing and scripting and most about the setting and looks and feel of the mission. <br/>

In the example we'll show how you can create a simple island hopping mission 

## Include Script

Firstly include the script. 
TODO: include link to release.


## Stages

So first of all think about the stages. Read the details about them here: [Stages](./Reference.html#stage)<br/>
These are logically ordered zones that will activate one by one based on the mission status in them. <br/>
There is a little more to it, but you'll find out. <br/>

Stages need to be named according to the convention: `MISSIONSTAGE_<OrderNumber>_<FreeForm>` <br/>
The first stage will be called `MISSIONSTAGE_1` or `MISSIONSTAGE_1_EAST` for example. <br/>

For this mission we started with the three stages: `MISSIONSTAGE_1_GROUND`, `MISSIONSTAGE_1_WATER` and `MISSIONSTAGE_2_AIRBASE` as you see in the image. <br/>
<img src="img/starting_stages.png" alt="drawing" width="1000"/>

In this example `_GROUND` and `_WATER` stages will be actived at the start of the mission. <br/>
`_AIRBASE` will however not be activated since the order number is 2 <br/>
`MISSIONSTAGE_3` will be used as part of this example as well. It's a stage even further away. <br/>


## Setting up CAP

If you don't want to use the CAP managers withing Spearhead you can skip this and continue to [setting up the missions](#setting-up-the-missions). <br/>
However CAP is one of the painpoints in a lot of missions and setting up a dynamic feeling airspace can be quite the challenge. <br/>
With the CAP managers we've tried to make this a lot easier. <br/>

A CAP group needs to follow the following naming convention: `CAP_<A|B><CONFIG>_<Free Form>`

For details on config read this: [CAP Group Config](./Reference.html#cap-group-config)
 
<img src="img/starting_stages.png" alt="drawing" width="35%"/>
<img src="img/starting_stages.png" alt="drawing" width="35%"/>
<br/>


## Setting up the missions