
# Spearhead

## For the Story tellers

Spearhead. A framework created for the mission maker. <br/>
For those who do want to create a mission with a story and progress, but do not want to get into scripting. Creating an engaging mission can be an incredible feat. First think of the mission, the submission, the placement, the time. Once the concept is done you'll need to place all the objects into the editor. Not too many, but also not too little. Then comes the scripts to make it feel engaging and organic. The latter is probably the biggest hurdle. 

Spearhead is created to try and make this entire process a lot easier.
It keeps track of completed missions, moves the stages forward once all mission are complete. <br/> Manages CAP in an easy to setup way (no scripting required) and gives a lot of possibilities to the mission maker. <br/>
The goal is for the mission maker to focus on the story and the detailed missions, without having to worry about all the triggers and mission management the scripts normally take care off.



- [How To]

## Concept

Spearhead is very naming convention heavy. It combines trigger-zones and naming conventions to detect all units and their configuration at the start of the mission and will then run from there. <br/>

#### Debugging

Working with naming conventions and the script only running when the mission starts causes the feedback to always be delayed. <br/>
We have found a way to make it very insightful for the mission maker. <br/>
The best way to do so is run the mission in single player. <br/>
Apart from seeing the mission unfold you will be able to see in the `DCS.log` if the mission parsing went correctly. <br/>
Open the `DCS.log` file and search for `[MISSIONPARSER]`. This should normally be totally on the bottom. <br/>
All issues found by the Spearhead parsers will be logged all at once. <br/>
Since Spearhead is built to not crash on issues, but merely ignore the issues groups/zones it's best to always check! <br/>
It might cause for weird side effects if you don't and there is groups not spawning for example. <br/>









## CAP


