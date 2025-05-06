
---@class Queue
---@field private _items Array
---@field private _first number
---@field private _last number
local Queue = {}
Queue.__index = Queue

---@return Queue
function Queue.new()

    local self = setmetatable({}, Queue)
    self._items = {}
    self._first = 1
    self._last = 0
    return self
end

---@return nil
function Queue:push(item)
    self._last = self._last + 1
    self._items[self._last] = item
end

---@return any?
function Queue:pop()
    if self._first > self._last then
        return nil
    end

    local item = self._items[self._first]
    self._items[self._first] = nil
    self._first = self._first + 1
    return item
end


---@return Array<any>
function Queue:toList()
    local items = {}
    for i = self._first, self._last do
        items[#items + 1] = self._items[i]
    end
    return items
end


if Spearhead == nil then Spearhead = {} end
if Spearhead._baseClasses == nil then Spearhead._baseClasses = {} end
Spearhead._baseClasses.Queue = Queue