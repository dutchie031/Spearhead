

---@class DrawingHelper
local DrawingHelper = {}
DrawingHelper.__index = DrawingHelper

local customDrawingIdIncrementer = 4210

---@param object DrawingObject
---@return integer? id
function DrawingHelper.Draw(object)
    if object == nil then
        return nil
    end

    local id = DrawingHelper.GetAndAddId()
    if(object.primitiveType == "Polygon") then
        DrawingHelper.DrawPolygon(object--[[@as Polygon]], id)
    elseif(object.primitiveType == "Line") then
        DrawingHelper.DrawLine(object--[[@as Line]], id)
    elseif(object.primitiveType == "TextBox") then
        DrawingHelper.DrawTextBox(object--[[@as TextBox]], id)
    end

    return id
end

function DrawingHelper.GetAndAddId()
    customDrawingIdIncrementer = customDrawingIdIncrementer + 1
    return customDrawingIdIncrementer
end

---@private
---@param shapeID ShapeId
---@param drawID integer
---@param points Array<Vec3>
---@param fillColor table
---@param lineColor table
local function  MarkupToAll(shapeID, drawID, points, fillColor, lineColor, lineStyle)

    local functionString = "trigger.action.markupToAll(" .. shapeID .. ", -1, " .. drawID .. ","
    for _, point in ipairs(points) do
        functionString = functionString .. " { x=" .. point.x .. ", y=0,z=" .. point.z .. "},"
    end
    functionString = functionString ..
        "{ " .. lineColor[1] .. "," .. lineColor[2] .. "," .. lineColor[3] .. "," .. lineColor[4] .. "}, " .. 
        "{ " .. fillColor[1] .. "," .. fillColor[2] .. "," .. fillColor[3] .. "," .. fillColor[4] .. "}, " .. 
        lineStyle .. ")"

    ---@diagnostic disable-next-line: deprecated
    local f, err = loadstring(functionString)
    if f then
        f()
    else
        env.error("Something failed when drawing complex drawing" .. err)
    end
    
end

---@private
---@param object Polygon
---@param id integer
function DrawingHelper.DrawPolygon(object, id)
    if object == nil then
        return
    end
    
    ---@param circle Circle
    local function DrawCircle(circle)
        local vec3 = { x = circle.mapX, y = 0, z = circle.mapY }
        local fillColor = DrawingHelper.ColorToColorTable(circle.fillColorString)
        local colorString = DrawingHelper.ColorToColorTable(circle.colorString)
        local style = DrawingHelper.ToLineStyleInteger(circle.style)
        trigger.action.circleToAll(-1, id, vec3, circle.radius, colorString, fillColor, style, true)
    end
    
    ---@param oval Oval
    local function DrawOval(oval)
        ---@type Array<Vec3>
        local points = {}
        local pointsNo = 30
        local angleStep = (2 * math.pi) / points
        
        local fillColor = DrawingHelper.ColorToColorTable(oval.fillColorString)
        local color = DrawingHelper.ColorToColorTable(oval.colorString)
        local lineStyle = DrawingHelper.ToLineStyleInteger(oval.style)

        for i = 1, pointsNo do
            local angle = i * angleStep
            local x = oval.mapX + (oval.r1 * math.cos(angle))
            local y = oval.mapY + (oval.r2 * math.sin(angle))
            table.insert(points, { x = x, y = 0, z = y } )
        end
        MarkupToAll(7, id, points, fillColor, color, lineStyle)
    end

    ---@param free Free
    local function DrawFree(free)
        local fillColor = DrawingHelper.ColorToColorTable(free.fillColorString)
        local color = DrawingHelper.ColorToColorTable(free.colorString)
        local lineStyle = DrawingHelper.ToLineStyleInteger(free.style)

        local points = {}
        for _, point in ipairs(free.points) do
            table.insert(points, { x = point.x, y = 0, z = point.y } )
        end
        MarkupToAll(7, id, points, fillColor, color, lineStyle)
    end

    ---@param rect Rect
    local function DrawRect(rect)
        local fillColor = DrawingHelper.ColorToColorTable(rect.fillColorString)
        local color = DrawingHelper.ColorToColorTable(rect.colorString)
        local lineStyle = DrawingHelper.ToLineStyleInteger(rect.style)

        local pointA = { x = rect.mapX, y = 0, z = rect.mapY }
        local pointB = { x = rect.mapX + rect.width, y = 0, z = rect.mapY + rect.height }
        trigger.action.rectToAll(-1, id, pointA, pointB, color, fillColor, lineStyle, true)
    end

    ---@param arrow Arrow
    local function DrawArrow(arrow)
        local fillColor = DrawingHelper.ColorToColorTable(arrow.fillColorString)
        local color = DrawingHelper.ColorToColorTable(arrow.colorString)
        local lineStyle = DrawingHelper.ToLineStyleInteger(arrow.style)

        local startPoint = { x = arrow.mapX, y = 0, z = arrow.mapY }
        local rad = math.rad(arrow.angle or 0)
        local length = arrow.length or 100
        local endPoint = { x = arrow.mapX + length * math.cos(rad), y = 0, z = arrow.mapY + length * math.sin(rad) }
        trigger.action.arrowToAll(-1, id, startPoint, endPoint, color, fillColor, lineStyle, true)
    end

    if object.polygonMode == "circle" then
        DrawCircle(object--[[@as Circle]])
    elseif object.polygonMode == "oval" then
        DrawOval(object--[[@as Oval]])
    elseif object.polygonMode == "free" then
        DrawFree(object--[[@as Free]])
    elseif object.polygonMode == "rect" then
        DrawRect(object--[[@as Rect]])
    elseif object.polygonMode == "arrow" then
        DrawArrow(object--[[@as Arrow]])
    end
end

---@private 
---@param object Line
---@param id integer
function DrawingHelper.DrawLine(object, id)

    ---@type Array<Vec3>
    local points = {}

    for _, point in ipairs(object.points) do
        table.insert(points, { x = point.x, y = 0, z = point.y } )
    end

    local color = DrawingHelper.ColorToColorTable(object.colorString)
    local lineStyle = DrawingHelper.ToLineStyleInteger(object.style)
    MarkupToAll(1, id, points, color, color, lineStyle)
end

---@private 
---@param object TextBox
---@param id integer
function DrawingHelper.DrawTextBox(object, id)
    trigger.action.textToAll(-1, id, { x= object.mapX, y = 0, z = object.mapY },
        DrawingHelper.ColorToColorTable(object.colorString),
        DrawingHelper.ColorToColorTable(object.fillColorString),
        object.fontSize or 12,
        true,
        object.text or "")
end

function DrawingHelper.Remove(id)
    trigger.action.removeMark(id)
end



---@param hexStr string
---@return table
function DrawingHelper.ColorToColorTable(hexStr)
    hexStr = hexStr:gsub("0x", "")
    local a = tonumber(hexStr:sub(1, 2), 16) / 255
    local r = tonumber(hexStr:sub(3, 4), 16) / 255
    local g = tonumber(hexStr:sub(5, 6), 16) / 255
    local b = tonumber(hexStr:sub(7, 8), 16) / 255

    return { r, g , b , a }
end

---@param lineStyle string
function DrawingHelper.ToLineStyleInteger(lineStyle)
    lineStyle = lineStyle:lower()
    if lineStyle == "no line" then
        return 0
    elseif lineStyle == "solid" then
        return 1
    elseif lineStyle == "dashed" then
        return 2
    elseif lineStyle == "dotted" then
        return 3
    elseif lineStyle == "dot dash" then
        return 4
    elseif lineStyle == "long dash" then
        return 5
    elseif lineStyle == "two dash" then
        return 6
    else
        return 0
    end
end

---@class ARGB
---@field public a number
---@field public r number
---@field public g number
---@field public b number


return DrawingHelper