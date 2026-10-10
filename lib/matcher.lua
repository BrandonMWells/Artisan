local matcher = {}

local function add_requirement(requirements, item_id, count)
    item_id = tonumber(item_id) or 0
    count = tonumber(count) or 0
    if item_id <= 0 or count <= 0 then
        return
    end
    requirements[item_id] = (requirements[item_id] or 0) + count
end

function matcher.get_requirements(recipe)
    local requirements = {}
    add_requirement(requirements, recipe.crystal, 1)
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        add_requirement(requirements, ingredient.id, ingredient.count)
    end
    return requirements
end

function matcher.get_max_crafts(recipe, owned)
    local maximum = nil
    for item_id, required in pairs(matcher.get_requirements(recipe)) do
        local available = tonumber(owned[item_id]) or 0
        local crafts = math.floor(available / required)
        if maximum == nil or crafts < maximum then
            maximum = crafts
        end
    end
    return maximum or 0
end

function matcher.find_craftable(recipes, owned)
    local result = {}
    for _, recipe in ipairs(recipes or {}) do
        local crafts = matcher.get_max_crafts(recipe, owned)
        if crafts > 0 then
            result[#result + 1] = { recipe = recipe, crafts = crafts }
        end
    end
    return result
end

return matcher
