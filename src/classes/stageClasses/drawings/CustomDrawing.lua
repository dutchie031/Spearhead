
local DrawingHelper = require("classes.stageClasses.drawings.helper.DrawingHelper")
local Util = require("classes.util.Util")

---@class CustomDrawing
---@field private _id integer?
---@field private _drawingObject DrawingObject
---@field private _startingStage number
---@field private _removeAtStage number
local CustomDrawing = {}
CustomDrawing.__index = CustomDrawing


---@param drawingObject DrawingObject
---@param id integer?
---@return CustomDrawing
function CustomDrawing.New(drawingObject, id)
    local self = setmetatable({}, CustomDrawing)
    self._drawingObject = drawingObject
    self._id = id

    local name = drawingObject.name
    local split = Util.split_string(name or "", "_")
    local secondPart = split[2] or "1"
    local splitPart = Util.split_string(secondPart, ":")
    self._startingStage = tonumber(splitPart[1]) or 1
    self._removeAtStage = tonumber(splitPart[2]) or math.huge
    return self
end

---@return number start
---@return number stop
function CustomDrawing:GetStartAndStop()
    return self._startingStage, self._removeAtStage
end

function CustomDrawing:Draw()
    self._id = DrawingHelper.Draw(self._drawingObject)
end

function CustomDrawing:Remove()
    if self._id ~= nil then
        DrawingHelper.Remove(self._id)
        self._id = nil
    end
end

return CustomDrawing