local ffi = require('ffi')
local d3d8 = require('d3d8')

local resources = {
    names = {},
    item_details = {},
    key_item_names = {},
    icons = {},
}

local device = d3d8.get_device()
local C = ffi.C

local function get_item(item_id)
    local ok, item = pcall(function ()
        return AshitaCore:GetResourceManager():GetItemById(item_id)
    end)
    return ok and item or nil
end

local function normalize_description(value)
    if type(value) ~= 'string' then
        return ''
    end
    local text = value:gsub('\r\n', '\n'):gsub('\r', '\n')
    text = text:gsub('\239\191\189', '?')
    text = text:gsub('\239\188\133', '%%')
    local elements = {
        'Fire', 'Ice', 'Wind', 'Earth',
        'Lightning', 'Water', 'Light', 'Dark',
    }
    text = text:gsub('\239(.)', function (byte)
        local value_byte = byte:byte(1)
        if value_byte >= 31 and value_byte <= 38 then
            return elements[value_byte - 30] .. ' '
        end
        return ''
    end)
    text = text:gsub('\30.', ''):gsub('\31.', '')
    text = text:gsub('[%z\1-\8\11\12\14-\31]', ' ')
    text = text:gsub('\194\160', ' ')
    text = text:gsub('[ \t]+', ' '):gsub(' *\n *', '\n')
    return text:match('^%s*(.-)%s*$') or ''
end

function resources.get_name(item_id)
    local cached = resources.names[item_id]
    if cached then
        return cached
    end
    local item = get_item(item_id)
    local name = item and item.Name and item.Name[1] or nil
    if not name or name == '' then
        name = ('Item %d'):format(tonumber(item_id) or 0)
    end
    resources.names[item_id] = name
    return name
end

function resources.get_item_details(item_id)
    local cached = resources.item_details[item_id]
    if cached then
        return cached
    end
    local item = get_item(item_id)
    local description = ''
    local ok_description, value = pcall(function ()
        return AshitaCore:GetResourceManager():GetString(
            'items.descriptions',
            item_id
        )
    end)
    if ok_description then
        description = normalize_description(value)
    end
    if description == '' and item and item.Description then
        description = normalize_description(item.Description[1])
    end
    local details = {
        name = resources.get_name(item_id),
        description = description,
        stack_size = item and (tonumber(item.StackSize) or 0) or 0,
        item_type = item and (tonumber(item.Type) or 0) or 0,
    }
    resources.item_details[item_id] = details
    return details
end

function resources.get_key_item_name(key_item_id)
    local cached = resources.key_item_names[key_item_id]
    if cached then
        return cached
    end
    local ok, key_item = pcall(function ()
        return AshitaCore:GetResourceManager():GetKeyItemById(key_item_id)
    end)
    local name = ok and key_item and key_item.Name and key_item.Name[1] or nil
    if not name or name == '' then
        name = ('Key Item %d'):format(tonumber(key_item_id) or 0)
    end
    resources.key_item_names[key_item_id] = name
    return name
end

function resources.get_icon(item_id)
    local cached = resources.icons[item_id]
    if cached ~= nil then
        return cached or nil
    end
    local item = get_item(item_id)
    if not item or not item.Bitmap or tonumber(item.ImageSize) == 0 then
        resources.icons[item_id] = false
        return nil
    end

    local texture_ptr = ffi.new('IDirect3DTexture8*[1]')
    local result = C.D3DXCreateTextureFromFileInMemoryEx(
        device, item.Bitmap, item.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
        C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT,
        0xFF000000, nil, nil, texture_ptr
    )
    if result ~= C.S_OK then
        resources.icons[item_id] = false
        return nil
    end
    local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]))
    resources.icons[item_id] = texture
    return texture
end

function resources.texture_pointer(texture)
    return tonumber(ffi.cast('uint32_t', texture))
end

function resources.clear()
    resources.names = {}
    resources.item_details = {}
    resources.key_item_names = {}
    resources.icons = {}
end

return resources
