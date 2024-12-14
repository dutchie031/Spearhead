
# Spearhead.API

the `Spearhead.API` space is specifically created to make sure mission makers can interact with the framework. 

Simply alter logic, get the current state in Spearhead, and give the whole ME more control. 

eg. Late activate the entire framework by calling `Spearhead.API.Stages.changeStage(1)` later or on demand and setting the starting config stage to -1 in the Spearhead configuration file


## Stages

```lua

---Changes the active stage of spearhead.
--- All other stages will change based on the normal logic. (CAP, BLUE etc.)
--- @param stageNumber number the stage number you want changed
--- @return boolean success indicator of success
--- @return string message error message
Spearhead.API.Stages.changeStage = function(stageNumber) 

---Returns the current stange number
---Returns nil when the stagenumber was not set before ever, which means Spearhead was not started.
---@return number | nil
Spearhead.API.Stages.getCurrentStage = function()


---returns whether a stage (by index) is complete. 
---@param stageNumber number
---@return boolean | nil
---@return string 
Spearhead.API.Stages.isStageComplete = function(stageNumber)

```



