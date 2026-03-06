---@class SpearheadAPI
---@field Stages SpearheadStagesAPI
---@field Missions MissionAPI
SpearheadAPI = SpearheadAPI

---@class SpearheadStagesAPI
---@field changeStage fun(stageNumber: number): boolean, string @Changes the active stage of spearhead. <br/> All other stages will change based on the normal logic. (CAP, BLUE etc.)
---@field getCurrentStage fun(): number | nil @Returns the current stange number <br/> Returns nil when the stagenumber was not set before ever, which means Spearhead was not started.
---@field isStageComplete fun(stageNumber: number): boolean | nil, string @returns whether a stage (by index) is complete. <br/> @param stageNumber number <br/> @return boolean | nil <br/> @return string

---@class OnMissionCompleteListener
---@field onMissionComplete fun(self: OnMissionCompleteListener, zone_name: string) @Called when a mission is completed. @return void

---@class MissionAPI 
---@field addOnMissionCompleteListener fun(listener: OnMissionCompleteListener) @Adds a listener to the mission. <br/> @param listener OnMissionCompleteListener <br/> @return void


