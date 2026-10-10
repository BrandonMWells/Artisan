package.path = package.path .. ';./?.lua;./?/init.lua'

local matcher = require('lib.matcher')

local recipe = {
    crystal = 4096,
    ingredients = {
        { id = 649, count = 2 },
        { id = 649, count = 1 },
        { id = 850, count = 2 },
    },
}

local requirements = matcher.get_requirements(recipe)
assert(requirements[4096] == 1, 'crystal must be required once per attempt')
assert(requirements[649] == 3, 'repeated ingredients must be aggregated')
assert(requirements[850] == 2, 'ingredient quantity must be preserved')

local owned = {
    [4096] = 5,
    [649] = 10,
    [850] = 7,
}
assert(matcher.get_max_crafts(recipe, owned) == 3, 'minimum owned/required ratio wins')

local second = {
    crystal = 4096,
    ingredients = { { id = 649, count = 5 } },
}
local matches = matcher.find_craftable({ recipe, second }, owned)
assert(matches[1].crafts == 3, 'each recipe must have an independent maximum')
assert(matches[2].crafts == 2, 'later recipes must not consume earlier recipe stock')

owned[4096] = 0
assert(matcher.get_max_crafts(recipe, owned) == 0, 'crystal ownership gates matching')

print('matcher tests passed')
