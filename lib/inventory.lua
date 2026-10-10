local inventory = {}

local INVALID_ITEM_ID = 65535
local CACHE_TTL_SECONDS = 0.25

local caches = {}

local function read_update_counter(manager)
    local ok, value = pcall(manager.GetContainerUpdateCounter, manager)
    if ok then
        return tonumber(value)
    end
    return nil
end

local function normalize_containers(container_ids)
    local containers = {}
    local seen = {}
    for _, value in ipairs(container_ids or { 0 }) do
        local container_id = tonumber(value)
        if container_id and container_id >= 0 and container_id <= 16
            and not seen[container_id] then
            seen[container_id] = true
            containers[#containers + 1] = container_id
        end
    end
    table.sort(containers)
    return containers, table.concat(containers, ',')
end

local function scan(manager, containers)
    local counts = {}
    for _, container_id in ipairs(containers) do
        local ok_max, max_slots = pcall(manager.GetContainerCountMax, manager, container_id)
        max_slots = ok_max and (tonumber(max_slots) or 0) or 0
        for slot_index = 1, max_slots do
            local ok_item, item = pcall(
                manager.GetContainerItem,
                manager,
                container_id,
                slot_index
            )
            local item_id = ok_item and item and (tonumber(item.Id) or 0) or 0
            local item_count = ok_item and item and (tonumber(item.Count) or 0) or 0
            if item_id > 0 and item_id ~= INVALID_ITEM_ID and item_count > 0 then
                counts[item_id] = (counts[item_id] or 0) + item_count
            end
        end
    end
    return counts
end

function inventory.invalidate()
    for _, cache in pairs(caches) do
        cache.checked_at = 0
        cache.update_counter = nil
    end
end

function inventory.get_counts(force_refresh, container_ids)
    local manager = AshitaCore:GetMemoryManager():GetInventory()
    if not manager then
        return {}
    end

    local containers, cache_key = normalize_containers(container_ids)
    local cache = caches[cache_key]
    if not cache then
        cache = { checked_at = 0, update_counter = nil, counts = {} }
        caches[cache_key] = cache
    end
    local now = os.clock()
    local update_counter = read_update_counter(manager)
    local counter_changed = update_counter ~= nil and update_counter ~= cache.update_counter
    local expired = (now - cache.checked_at) >= CACHE_TTL_SECONDS
    if force_refresh or counter_changed or expired or cache.checked_at == 0 then
        cache.counts = scan(manager, containers)
        cache.checked_at = now
        cache.update_counter = update_counter
    end
    return cache.counts
end

return inventory
