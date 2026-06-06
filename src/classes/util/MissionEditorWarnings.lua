
---@class MissionEditingWarnings
local MissionEditingWarnings = {}
function MissionEditingWarnings.Add(warningMessage)
    table.insert(MissionEditingWarnings, warningMessage or "skip")
end

---@param logger Logger
function MissionEditingWarnings.WriteAll(logger)

    if not logger then
        return
    end

    if not MissionEditingWarnings or #MissionEditingWarnings == 0 then
        return
    end

    logger:warn("Mission Editor Warnings:")
    for _, warning in ipairs(MissionEditingWarnings) do
        logger:warn("- " .. warning)
    end

end

return MissionEditingWarnings