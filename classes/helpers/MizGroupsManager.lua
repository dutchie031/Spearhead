---@class SpawnData
---@field groupTemplate table
---@field isStatic boolean
---@field category number
---@field country number

---@class MizGroupsManager
---@field private _groupNames Array<string>
---@field private _spawnTemplateData table<string, SpawnData>
local MizGroupsManager = {}

MizGroupsManager._groupNames = {}
MizGroupsManager._spawnTemplateData = {}

do --init
    for coalition_name, coalition_data in pairs(env.mission.coalition) do
        local coalition_nr = Spearhead.DcsUtil.stringToCoalition(coalition_name)
        if coalition_data.country then
            for country_index, country_data in pairs(coalition_data.country) do
                for category_name, categorydata in pairs(country_data) do
                    local category_id = Spearhead.DcsUtil.stringToGroupCategory(category_name)
                    if category_id ~= nil and type(categorydata) == "table" and categorydata.group ~= nil and type(categorydata.group) == "table" then
                        for group_index, group in pairs(categorydata.group) do
                            local name = group.name
                            local skippable = false
                            local isStatic = false
                            if category_id == Spearhead.DcsUtil.GroupCategory.STATIC then
                                isStatic = true
                                local unit = group.units[1]
                                if unit and unit.category == "Heliports" then
                                    skippable = true
                                elseif unit and unit.name then
                                    name = unit.name
                                else
                                    env.error("Group " .. name .. " has no units, skipping it.")
                                    skippable = true
                                end
                            end

                            if skippable == false then
                                MizGroupsManager._spawnTemplateData[name] =
                                {
                                    isStatic = isStatic,
                                    country = country_data.id,
                                    category = category_id,
                                    groupTemplate = group
                                }
                                table.insert(MizGroupsManager._groupNames, name)
                            end
                        end
                    end
                end
            end
        end
    end
end

---@return Array<string>
function MizGroupsManager.getAllGroupNames()
    return MizGroupsManager._groupNames
end

---@return boolean?
---@param groupName string
function MizGroupsManager.IsGroupStatic(groupName)
    local spawnData = MizGroupsManager._spawnTemplateData[groupName]
    if spawnData then
        return spawnData.isStatic
    end
    return nil
end

---@return SpawnData?
function MizGroupsManager.getSpawnTemplateData(groupName)
    return MizGroupsManager._spawnTemplateData[groupName]
end

if not Spearhead then Spearhead = {} end
if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.helpers then Spearhead.classes.helpers = {} end
Spearhead.classes.helpers.MizGroupsManager = MizGroupsManager
