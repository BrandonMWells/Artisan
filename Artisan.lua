addon.name = 'Artisan'
addon.author = 'Elith'
addon.version = '0.22.1'
addon.desc = 'Read-only crafting reference from the player inventory and craft skills.'
addon.link = 'https://github.com/BrandonMWells/Artisan'

-- Changelog (newest first; keep entries concise):
-- 0.22.1 - Keeps open tracker categories expanded during inventory updates.
-- 0.22.0 - Initial public release.
-- 0.21.0 - Completed all eight craft books and added contextual help.
-- 0.20.0 - Added the complete Phoenix-era Leathercraft book, key items, and rank tests.
-- 0.19.0 - Added material recipe jumps, persistent highlighting, and stable bookmarks.
-- 0.18.0 - Added the complete Phoenix-era Goldsmithing book, key items, and rank tests.
-- 0.17.0 - Added the complete Phoenix-era Bonecraft book, key items, and rank tests.
-- 0.16.0 - Added the complete Phoenix-era Alchemy book, key items, and rank tests.
-- 0.15.0 - Added Clothcraft, tie-aware cross-book recipes, and remembered categories.
-- 0.14.0 - Added the draggable minimized launcher and configurable window-close behavior.
-- 0.13.3 - Established the Smithing/Woodworking books, filters, bookmarks, and themed UI.

require('common')

local bit = require('bit')
local chat = require('chat')
local imgui = require('imgui')
local settings = require('settings')

local crafts = require('data.crafts')
local key_item_names = require('data.key_items')
local rank_tests = require('data.rank_tests')
local inventory = require('lib.inventory')
local matcher = require('lib.matcher')
local resources = require('lib.resources')

local MAX_VISIBLE_CRAFTABLE_RECIPES = 5
local MAX_RECIPE_SEARCH_RESULTS = 50
local CRAFTBOOK_VISIBLE_RECIPE_TARGET = 6
local CRAFTBOOK_CHROME_HEIGHT = 125
local CRAFTBOOK_TYPICAL_RECIPE_HEIGHT = 92
local MAX_RECIPE_SKILL_GAP = 15
local WINDOW_FLAGS = bit.bor(
    ImGuiWindowFlags_NoCollapse or 0,
    ImGuiWindowFlags_NoDocking or 0
)
local CRAFT_NAMES = {
    'woodworking', 'smithing', 'clothcraft', 'alchemy',
    'bonecraft', 'goldsmithing', 'leathercraft', 'cooking',
}
local CRAFTBOOK_DATA = {
    woodworking = require('data.woodworking'),
    smithing = require('data.smithing'),
    clothcraft = require('data.clothcraft'),
    alchemy = require('data.alchemy'),
    bonecraft = require('data.bonecraft'),
    goldsmithing = require('data.goldsmithing'),
    leathercraft = require('data.leathercraft'),
    cooking = require('data.cooking'),
}

local CRAFT_RANKS = {
    { name = 'AMATEUR', min = 0, max = 10 },
    { name = 'RECRUIT', min = 11, max = 20 },
    { name = 'INITIATE', min = 21, max = 30 },
    { name = 'NOVICE', min = 31, max = 40 },
    { name = 'APPRENTICE', min = 41, max = 50 },
    { name = 'JOURNEYMAN', min = 51, max = 60 },
    { name = 'CRAFTSMAN', min = 61, max = 70 },
    { name = 'ARTISAN', min = 71, max = 80 },
    { name = 'ADEPT', min = 81, max = 90 },
    { name = 'VETERAN', min = 91, max = 100 },
    { name = 'EXPERT', min = 101, max = 110 },
}

local MATERIAL_SOURCES = {
    { setting = 'source_inventory', label = 'Inventory', containers = { 0 } },
    { setting = 'source_safe', label = 'Mog Safe', containers = { 1 } },
    { setting = 'source_safe2', label = 'Mog Safe 2', containers = { 9 } },
    { setting = 'source_storage', label = 'Storage', containers = { 2 } },
    { setting = 'source_locker', label = 'Mog Locker', containers = { 4 } },
    { setting = 'source_satchel', label = 'Mog Satchel', containers = { 5 } },
    { setting = 'source_sack', label = 'Mog Sack', containers = { 6 } },
    { setting = 'source_case', label = 'Mog Case', containers = { 7 } },
    { setting = 'source_wardrobe1', label = 'Mog Wardrobe 1', containers = { 8 }, wardrobe = true },
    { setting = 'source_wardrobe2', label = 'Mog Wardrobe 2', containers = { 10 }, wardrobe = true },
    { setting = 'source_wardrobe3', label = 'Mog Wardrobe 3', containers = { 11 }, wardrobe = true },
    { setting = 'source_wardrobe4', label = 'Mog Wardrobe 4', containers = { 12 }, wardrobe = true },
    { setting = 'source_wardrobe5', label = 'Mog Wardrobe 5', containers = { 13 }, wardrobe = true },
    { setting = 'source_wardrobe6', label = 'Mog Wardrobe 6', containers = { 14 }, wardrobe = true },
    { setting = 'source_wardrobe7', label = 'Mog Wardrobe 7', containers = { 15 }, wardrobe = true },
    { setting = 'source_wardrobe8', label = 'Mog Wardrobe 8', containers = { 16 }, wardrobe = true },
}

local THEME_SETTINGS_VERSION = 2

local default_settings = T{
    visible = true,
    locked = false,
    source_inventory = true,
    source_safe = true,
    source_safe2 = true,
    source_storage = true,
    source_locker = true,
    source_satchel = true,
    source_sack = true,
    source_case = true,
    source_wardrobe1 = true,
    source_wardrobe2 = true,
    source_wardrobe3 = true,
    source_wardrobe4 = true,
    source_wardrobe5 = true,
    source_wardrobe6 = true,
    source_wardrobe7 = true,
    source_wardrobe8 = true,
    scale = 1.0,
    position_x = 80,
    position_y = 180,
    launcher_position_x = 80,
    launcher_position_y = 180,
    launcher_position_initialized = false,
    launcher_scale = 1.0,
    artisan_button_shape = 'box',
    show_artisan_button = true,
    show_recipe_craft_count = true,
    close_all_windows_with_artisan = true,
    show_empty_crafts = true,
    remember_opened_categories = false,
    opened_categories = T{},
    remember_jump_location = false,
    window_color_r = 0.045,
    window_color_g = 0.040,
    window_color_b = 0.038,
    window_opacity = 0.95,
    bookmarks = T{},
    font_color_r = 0.92,
    font_color_g = 0.90,
    font_color_b = 0.86,
    accent_color_r = 0.94,
    accent_color_g = 0.65,
    accent_color_b = 0.33,
    theme_settings_version = 0,
    useful_min = 2,
    useful_max = 5,
    risky_min = 6,
    risky_max = 15,
    hq1 = 11,
}

local state = {
    settings = settings.load(default_settings),
    visible = { true },
    settings_open = { false },
    craftbook_open = { false },
    recipe_search = { '' },
    filters_open = { false },
    colors_open = { false },
    color_picker_open = { false },
    color_picker_target = nil,
    color_picker_pending = false,
    color_picker_x = 0,
    color_picker_y = 0,
    position_applied = false,
    craftbook_position_applied = false,
    filters_position_applied = false,
    colors_position_applied = false,
    launcher_position_applied = false,
    launcher_dragged = false,
    category_open = {},
    category_force_closed = {},
    category_force_open = {},
    tracker_was_visible = false,
    craftbook_was_open = false,
    craftbook_craft = 'smithing',
    recipe_jump_target = nil,
    recipe_jump_category_key = nil,
    recipe_jump_scroll_pending = false,
    recipe_jump_highlight_active = false,
    pending_recipe_jump = nil,
    tracker_material_popup_item_id = nil,
    tracker_material_popup_pending = false,
    tracker_material_popup_x = 0,
    tracker_material_popup_y = 0,
    help_open = { false },
    help_context = 'artisan',
    titlebar_help_rects = {},
    artisan_window_x = nil,
    artisan_window_y = nil,
    artisan_window_width = nil,
    pending_ui_scale = nil,
}
state.visible[1] = state.settings.visible == true

local function reset_theme_settings()
    state.settings.window_color_r = default_settings.window_color_r
    state.settings.window_color_g = default_settings.window_color_g
    state.settings.window_color_b = default_settings.window_color_b
    state.settings.window_opacity = default_settings.window_opacity
    state.settings.link_theme_colors = nil
    state.settings.font_color_r = default_settings.font_color_r
    state.settings.font_color_g = default_settings.font_color_g
    state.settings.font_color_b = default_settings.font_color_b
    state.settings.accent_color_r = default_settings.accent_color_r
    state.settings.accent_color_g = default_settings.accent_color_g
    state.settings.accent_color_b = default_settings.accent_color_b
    state.settings.theme_settings_version = THEME_SETTINGS_VERSION
end

-- Convert the original string launcher shape to the boolean used by the renderer.
if state.settings.artisan_button_rounded == nil then
    state.settings.artisan_button_rounded =
        state.settings.artisan_button_shape == 'rounded'
    settings.save()
end

-- Reset stored theme values when the theme schema changes.
if (tonumber(state.settings.theme_settings_version) or 0) < THEME_SETTINGS_VERSION then
    reset_theme_settings()
    settings.save()
end
state.settings.risky_min = math.max(
    (tonumber(state.settings.useful_max) or default_settings.useful_max) + 1,
    math.min(
        MAX_RECIPE_SKILL_GAP,
        tonumber(state.settings.risky_min) or default_settings.risky_min
    )
)
state.settings.risky_max = math.max(
    state.settings.risky_min,
    math.min(
        MAX_RECIPE_SKILL_GAP,
        tonumber(state.settings.risky_max) or default_settings.risky_max
    )
)

-- Expand the original Wardrobes toggle into one setting per wardrobe.
if state.settings.source_wardrobes ~= nil then
    local enabled = state.settings.source_wardrobes ~= false
    for index = 1, 8 do
        state.settings['source_wardrobe' .. tostring(index)] = enabled
    end
    state.settings.source_wardrobes = nil
    settings.save()
end

local COLORS = {
    background = { 0.045, 0.040, 0.038, 0.95 },
    child_bg = { 0.055, 0.050, 0.046, 0.72 },
    border = { 0.56, 0.38, 0.22, 0.90 },
    separator = { 0.42, 0.30, 0.20, 0.70 },
    heading = { 0.94, 0.65, 0.33, 1.00 },
    white = { 0.92, 0.90, 0.86, 1.00 },
    green = { 0.35, 0.90, 0.52, 1.00 },
    red = { 0.95, 0.38, 0.38, 1.00 },
    gray = { 0.66, 0.63, 0.58, 1.00 },
    yellow = { 0.98, 0.80, 0.30, 1.00 },
    missing_bg = { 0.55, 0.04, 0.04, 0.90 },
    missing_tint = { 1.00, 0.35, 0.35, 1.00 },
    title = { 0.10, 0.08, 0.065, 1.00 },
    title_active = { 0.22, 0.14, 0.085, 1.00 },
    frame = { 0.11, 0.10, 0.09, 1.00 },
    frame_hovered = { 0.18, 0.15, 0.12, 1.00 },
    frame_active = { 0.26, 0.19, 0.13, 1.00 },
    button = { 0.20, 0.14, 0.10, 1.00 },
    button_hovered = { 0.33, 0.22, 0.13, 1.00 },
    button_active = { 0.46, 0.29, 0.14, 1.00 },
    button_selected = { 0.035, 0.030, 0.028, 1.00 },
    button_selected_hovered = { 0.09, 0.07, 0.05, 1.00 },
    button_selected_active = { 0.14, 0.10, 0.065, 1.00 },
    header = { 0.13, 0.11, 0.09, 1.00 },
    header_hovered = { 0.24, 0.17, 0.11, 1.00 },
    header_active = { 0.34, 0.22, 0.12, 1.00 },
    scrollbar_bg = { 0.025, 0.025, 0.024, 0.90 },
    scrollbar = { 0.32, 0.24, 0.17, 1.00 },
    scrollbar_hovered = { 0.48, 0.33, 0.19, 1.00 },
    scrollbar_active = { 0.64, 0.42, 0.21, 1.00 },
}

local ARTISAN_THEME_COLOR_COUNT = 26
local ARTISAN_THEME_STYLE_COUNT = 5

local function mix_color(left, right, amount, alpha)
    return {
        left[1] + ((right[1] - left[1]) * amount),
        left[2] + ((right[2] - left[2]) * amount),
        left[3] + ((right[3] - left[3]) * amount),
        alpha or 1.0,
    }
end

local function shade_color(color, amount, alpha)
    return {
        math.max(0.0, math.min(1.0, color[1] * amount)),
        math.max(0.0, math.min(1.0, color[2] * amount)),
        math.max(0.0, math.min(1.0, color[3] * amount)),
        alpha or 1.0,
    }
end

local function update_theme_accents(background)
    local accent = {
        tonumber(state.settings.accent_color_r) or default_settings.accent_color_r,
        tonumber(state.settings.accent_color_g) or default_settings.accent_color_g,
        tonumber(state.settings.accent_color_b) or default_settings.accent_color_b,
        1.0,
    }
    local using_default_accent =
        math.abs(accent[1] - default_settings.accent_color_r) < 0.001 and
        math.abs(accent[2] - default_settings.accent_color_g) < 0.001 and
        math.abs(accent[3] - default_settings.accent_color_b) < 0.001
    local using_default_background =
        math.abs(background[1] - default_settings.window_color_r) < 0.001 and
        math.abs(background[2] - default_settings.window_color_g) < 0.001 and
        math.abs(background[3] - default_settings.window_color_b) < 0.001

    if using_default_accent and using_default_background then
        COLORS.border = { 0.56, 0.38, 0.22, 0.90 }
        COLORS.separator = { 0.42, 0.30, 0.20, 0.70 }
        COLORS.heading = { 0.94, 0.65, 0.33, 1.00 }
        COLORS.title = { 0.10, 0.08, 0.065, 1.00 }
        COLORS.title_active = { 0.22, 0.14, 0.085, 1.00 }
        COLORS.frame = { 0.11, 0.10, 0.09, 1.00 }
        COLORS.frame_hovered = { 0.18, 0.15, 0.12, 1.00 }
        COLORS.frame_active = { 0.26, 0.19, 0.13, 1.00 }
        COLORS.button = { 0.20, 0.14, 0.10, 1.00 }
        COLORS.button_hovered = { 0.33, 0.22, 0.13, 1.00 }
        COLORS.button_active = { 0.46, 0.29, 0.14, 1.00 }
        COLORS.button_selected = { 0.035, 0.030, 0.028, 1.00 }
        COLORS.button_selected_hovered = { 0.09, 0.07, 0.05, 1.00 }
        COLORS.button_selected_active = { 0.14, 0.10, 0.065, 1.00 }
        COLORS.header = { 0.13, 0.11, 0.09, 1.00 }
        COLORS.header_hovered = { 0.24, 0.17, 0.11, 1.00 }
        COLORS.header_active = { 0.34, 0.22, 0.12, 1.00 }
        COLORS.scrollbar = { 0.32, 0.24, 0.17, 1.00 }
        COLORS.scrollbar_hovered = { 0.48, 0.33, 0.19, 1.00 }
        COLORS.scrollbar_active = { 0.64, 0.42, 0.21, 1.00 }
        return
    end

    local opaque_background = {
        background[1],
        background[2],
        background[3],
        1.0,
    }
    COLORS.heading = accent
    COLORS.border = {
        accent[1] * 0.62,
        accent[2] * 0.62,
        accent[3] * 0.62,
        0.90,
    }
    COLORS.separator = {
        accent[1] * 0.46,
        accent[2] * 0.46,
        accent[3] * 0.46,
        0.70,
    }
    COLORS.title = mix_color(opaque_background, accent, 0.10)
    COLORS.title_active = mix_color(opaque_background, accent, 0.24)
    COLORS.frame = mix_color(opaque_background, accent, 0.10)
    COLORS.frame_hovered = mix_color(opaque_background, accent, 0.20)
    COLORS.frame_active = mix_color(opaque_background, accent, 0.31)
    COLORS.button = shade_color(opaque_background, 0.72)
    COLORS.button_hovered = shade_color(opaque_background, 0.86)
    COLORS.button_active = shade_color(opaque_background, 1.00)
    COLORS.button_selected = shade_color(opaque_background, 0.48)
    COLORS.button_selected_hovered = shade_color(opaque_background, 0.62)
    COLORS.button_selected_active = shade_color(opaque_background, 0.76)
    COLORS.header = mix_color(opaque_background, accent, 0.13)
    COLORS.header_hovered = mix_color(opaque_background, accent, 0.27)
    COLORS.header_active = mix_color(opaque_background, accent, 0.40)
    COLORS.scrollbar = mix_color(opaque_background, accent, 0.30)
    COLORS.scrollbar_hovered = mix_color(opaque_background, accent, 0.48)
    COLORS.scrollbar_active = mix_color(opaque_background, accent, 0.66)
end

local function push_artisan_theme(scale)
    local background = {
        tonumber(state.settings.window_color_r) or COLORS.background[1],
        tonumber(state.settings.window_color_g) or COLORS.background[2],
        tonumber(state.settings.window_color_b) or COLORS.background[3],
        tonumber(state.settings.window_opacity) or COLORS.background[4],
    }
    COLORS.white = {
        tonumber(state.settings.font_color_r) or default_settings.font_color_r,
        tonumber(state.settings.font_color_g) or default_settings.font_color_g,
        tonumber(state.settings.font_color_b) or default_settings.font_color_b,
        1.0,
    }
    update_theme_accents(background)
    local child_background = {
        math.min(1.0, background[1] + 0.01),
        math.min(1.0, background[2] + 0.01),
        math.min(1.0, background[3] + 0.01),
        background[4] * 0.75,
    }
    imgui.PushStyleColor(ImGuiCol_Text, COLORS.white)
    imgui.PushStyleColor(ImGuiCol_TextDisabled, COLORS.gray)
    imgui.PushStyleColor(ImGuiCol_WindowBg, background)
    imgui.PushStyleColor(ImGuiCol_ChildBg, child_background)
    imgui.PushStyleColor(ImGuiCol_PopupBg, background)
    imgui.PushStyleColor(ImGuiCol_Border, COLORS.border)
    imgui.PushStyleColor(ImGuiCol_Separator, COLORS.separator)
    imgui.PushStyleColor(ImGuiCol_TitleBg, COLORS.title)
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, COLORS.title_active)
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, COLORS.title)
    imgui.PushStyleColor(ImGuiCol_FrameBg, COLORS.frame)
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, COLORS.frame_hovered)
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, COLORS.frame_active)
    imgui.PushStyleColor(ImGuiCol_Button, COLORS.button)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.button_hovered)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.button_active)
    imgui.PushStyleColor(ImGuiCol_Header, COLORS.header)
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, COLORS.header_hovered)
    imgui.PushStyleColor(ImGuiCol_HeaderActive, COLORS.header_active)
    imgui.PushStyleColor(ImGuiCol_CheckMark, COLORS.heading)
    imgui.PushStyleColor(ImGuiCol_SliderGrab, COLORS.scrollbar_hovered)
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, COLORS.scrollbar_active)
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, COLORS.scrollbar_bg)
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, COLORS.scrollbar)
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, COLORS.scrollbar_hovered)
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, COLORS.scrollbar_active)

    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 8 * scale, 4 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 3 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 10 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarRounding, 4 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding, 2 * scale)
end

local function pop_artisan_theme()
    imgui.PopStyleVar(ARTISAN_THEME_STYLE_COUNT)
    imgui.PopStyleColor(ARTISAN_THEME_COLOR_COUNT)
end

local function draw_titlebar_help_button(context, scale)
    local window_x, window_y = imgui.GetWindowPos()
    local window_width = imgui.GetWindowWidth()
    if context == 'artisan' then
        state.artisan_window_x = window_x
        state.artisan_window_y = window_y
        state.artisan_window_width = window_width
    end
    local button_size = imgui.GetFontSize()
    local frame_padding_x = 8 * scale
    local frame_padding_y = 4 * scale
    local close_button_x = window_x + window_width - frame_padding_x - button_size
    local button_min = {
        close_button_x - button_size - (2 * scale),
        window_y + frame_padding_y,
    }
    local button_max = {
        button_min[1] + button_size,
        button_min[2] + button_size,
    }
    state.titlebar_help_rects[context] = {
        minimum = button_min,
        maximum = button_max,
    }
    local cursor_x, cursor_y = imgui.GetCursorScreenPos()

    imgui.PushClipRect(button_min, button_max, false)
    imgui.SetCursorScreenPos(button_min)
    local clicked = imgui.InvisibleButton(
        '##TitlebarHelp_' .. context,
        { button_size, button_size },
        0
    )
    local hovered = imgui.IsItemHovered()
    local active = imgui.IsItemActive()

    local draw_list = imgui.GetWindowDrawList()
    if hovered or active then
        draw_list:AddRectFilled(
            button_min,
            button_max,
            imgui.GetColorU32(active and COLORS.button_active or COLORS.button_hovered),
            2 * scale
        )
    end
    local text_width, text_height = imgui.CalcTextSize('?')
    draw_list:AddText(
        {
            button_min[1] + ((button_size - text_width) / 2),
            button_min[2] + (2 * scale) - 2,
        },
        imgui.GetColorU32(COLORS.white),
        '?'
    )
    imgui.SetCursorScreenPos({ cursor_x, cursor_y })
    imgui.PopClipRect()

    if clicked then
        state.help_context = context
        state.help_open[1] = true
    end
end

local function is_titlebar_help_hovered(context)
    local rect = state.titlebar_help_rects[context]
    return rect ~= nil
        and imgui.IsMouseHoveringRect(rect.minimum, rect.maximum, false)
end

local function draw_main_titlebar_version(scale)
    local label = 'v' .. addon.version
    local text_width, text_height = imgui.CalcTextSize(label)
    local window_x, window_y = imgui.GetWindowPos()
    local window_width = imgui.GetWindowWidth()
    local button_size = imgui.GetFontSize()
    local frame_padding_x = 8 * scale
    local frame_padding_y = 4 * scale
    local close_button_x = window_x + window_width - frame_padding_x - button_size
    local help_button_x = close_button_x - button_size - (2 * scale)
    local text_x = help_button_x - (6 * scale) - text_width
    -- Align the version text with the titlebar controls' visual baseline.
    local text_y = window_y + frame_padding_y + (2 * scale) - 2

    local text_min = { text_x, text_y }
    local text_max = { text_x + text_width, text_y + text_height }
    imgui.PushClipRect(text_min, text_max, false)
    imgui.GetWindowDrawList():AddText(
        { text_x, text_y },
        imgui.GetColorU32(COLORS.white),
        label
    )
    imgui.PopClipRect()
end

local function say(message)
    print(chat.header(addon.name):append(chat.message(message)))
end

local function get_ui_scale()
    return math.max(0.75, math.min(3.0, tonumber(state.settings.scale) or 1.0))
end

local function push_scaled_font(scale)
    local active_font = imgui.GetFont()
    if active_font == nil then
        return false
    end
    return pcall(function ()
        imgui.PushFont(active_font, math.floor(14 * scale))
    end)
end

local function get_material_containers()
    local containers = {}
    for _, source in ipairs(MATERIAL_SOURCES) do
        if state.settings[source.setting] ~= false then
            for _, container_id in ipairs(source.containers) do
                containers[#containers + 1] = container_id
            end
        end
    end
    return containers
end

local function render_section_bar(label)
    if imgui.SeparatorText ~= nil then
        imgui.PushStyleColor(ImGuiCol_Text, COLORS.heading)
        imgui.PushStyleVar(ImGuiStyleVar_SeparatorTextAlign, { 0.5, 0.5 })
        imgui.SeparatorText(' ' .. label .. ' ')
        imgui.PopStyleVar()
        imgui.PopStyleColor()
    else
        imgui.TextColored(COLORS.heading, label)
        imgui.Separator()
    end
end

local function save_settings()
    state.settings.visible = state.visible[1]
    settings.save()
end

local function render_category_header(label, category_key, preserve_runtime_state)
    if state.category_force_open[category_key] then
        imgui.SetNextItemOpen(true, ImGuiCond_Always)
        state.category_force_open[category_key] = nil
        state.category_force_closed[category_key] = nil
        state.category_open[category_key] = true
    elseif state.category_force_closed[category_key] then
        imgui.SetNextItemOpen(false, ImGuiCond_Always)
        state.category_force_closed[category_key] = nil
        state.category_open[category_key] = false
    elseif state.settings.remember_opened_categories == true then
        if type(state.settings.opened_categories) ~= 'table' then
            state.settings.opened_categories = T{}
        end
        imgui.SetNextItemOpen(
            state.settings.opened_categories[category_key] == true,
            ImGuiCond_Always
        )
    elseif preserve_runtime_state and
        state.category_open[category_key] ~= nil then
        imgui.SetNextItemOpen(
            state.category_open[category_key] == true,
            ImGuiCond_Always
        )
    end

    local opened = imgui.CollapsingHeader(label)
    state.category_open[category_key] = opened
    if state.settings.remember_opened_categories == true and
        imgui.IsItemToggledOpen() then
        state.settings.opened_categories[category_key] = opened
        save_settings()
    end
    return opened
end

local function collapse_tracker_categories()
    for _, craft_name in ipairs(CRAFT_NAMES) do
        state.category_force_closed['tracker:' .. craft_name] = true
    end
end

local function collapse_craftbook_categories(craft_name, include_bookmarks)
    if include_bookmarks then
        state.category_force_closed['craftbook:bookmarks'] = true
    end
    state.category_force_closed[
        ('craftbook:%s:rank_tests'):format(craft_name)
    ] = true
    for _, rank in ipairs(CRAFT_RANKS) do
        local category_key = ('craftbook:%s:%s'):format(craft_name, rank.name)
        state.category_force_closed[category_key] = true
    end
end

local function get_player()
    return AshitaCore:GetMemoryManager():GetPlayer()
end

local function get_craft_skill(player, craft_name)
    if not player then
        return 0
    end
    local craft = crafts[craft_name]
    if not craft then
        return 0
    end
    local ok_entry, entry = pcall(player.GetCraftSkill, player, craft.skill_index)
    if not ok_entry or not entry then
        return 0
    end
    local ok_skill, skill = pcall(entry.GetSkill, entry)
    return ok_skill and (tonumber(skill) or 0) or 0
end

local function render_craft_levels(player, scale)
    local available_width = imgui.GetContentRegionAvail()
    imgui.Columns(2, '##ArtisanCraftLevels', false)
    imgui.SetColumnWidth(0, available_width / 2)
    for index, craft_name in ipairs(CRAFT_NAMES) do
        local craft = crafts[craft_name]
        local row_start = imgui.GetCursorPosX()
        imgui.TextColored(COLORS.gray, craft.label:upper())
        imgui.SameLine()
        imgui.SetCursorPosX(row_start + (118 * scale))
        imgui.TextColored(COLORS.white, tostring(get_craft_skill(player, craft_name)))
        if index < #CRAFT_NAMES then
            imgui.NextColumn()
        end
    end
    imgui.Columns(1)
end

local function can_attempt_recipe(player, recipe, primary_craft)
    if get_craft_skill(player, primary_craft) < (tonumber(recipe.cap) or 0) - MAX_RECIPE_SKILL_GAP then
        return false
    end
    for _, requirement in ipairs(recipe.subcrafts or {}) do
        local required_skill = tonumber(requirement.cap) or 0
        if get_craft_skill(player, requirement.craft) < required_skill - MAX_RECIPE_SKILL_GAP then
            return false
        end
    end
    return true
end

local function has_required_key_item(player, recipe)
    local key_item = tonumber(recipe.key_item) or 0
    if key_item == 0 then
        return true
    end
    local ok, owned = pcall(player.HasKeyItem, player, key_item)
    return ok and owned == true
end

local function get_available_recipes(player, counts, craft_name, recipe_list)
    local eligible = {}
    for _, recipe in ipairs(recipe_list or {}) do
        if has_required_key_item(player, recipe)
            and can_attempt_recipe(player, recipe, craft_name) then
            eligible[#eligible + 1] = recipe
        end
    end
    return matcher.find_craftable(eligible, counts)
end

local function get_recipe_color(cap, skill)
    local delta = cap - skill
    local difficult_max = tonumber(state.settings.risky_max)
        or MAX_RECIPE_SKILL_GAP
    if skill - cap >= state.settings.hq1 then
        return COLORS.yellow
    end
    if delta <= 0 then
        return COLORS.white
    end
    if delta >= state.settings.risky_min and delta <= difficult_max then
        return COLORS.red
    end
    if delta >= state.settings.useful_min and delta <= state.settings.useful_max then
        return COLORS.green
    end
    return COLORS.white
end

local function get_requirement_ids(recipe)
    local requirements = matcher.get_requirements(recipe)
    local crystal_id = tonumber(recipe.crystal) or 0
    local ingredient_ids = {}
    for item_id, required in pairs(requirements) do
        if item_id ~= crystal_id and required > 0 then
            ingredient_ids[#ingredient_ids + 1] = item_id
        end
    end
    table.sort(ingredient_ids)

    local ordered = {}
    for _, item_id in ipairs(ingredient_ids) do
        ordered[#ordered + 1] = item_id
    end
    return ordered, requirements
end

local function get_bookmark_key(craft_name, recipe)
    return craft_name .. ':' .. tostring(recipe.id)
end

local function find_bookmark_index(bookmark_key)
    for index, saved_key in ipairs(state.settings.bookmarks or {}) do
        if tostring(saved_key) == bookmark_key then
            return index
        end
    end
    return nil
end

local function is_recipe_bookmarked(bookmark_key)
    return find_bookmark_index(bookmark_key) ~= nil
end

local function set_recipe_bookmarked(bookmark_key, bookmarked)
    if type(state.settings.bookmarks) ~= 'table' then
        state.settings.bookmarks = T{}
    end
    local index = find_bookmark_index(bookmark_key)
    local changed = false
    if bookmarked and not index then
        state.settings.bookmarks[#state.settings.bookmarks + 1] = bookmark_key
        changed = true
    elseif not bookmarked and index then
        table.remove(state.settings.bookmarks, index)
        changed = true
    end

    if changed then
        local category_key = 'craftbook:bookmarks'
        local was_open = state.category_open[category_key] == true
        state.category_force_open[category_key] = nil
        state.category_force_closed[category_key] = nil
        if was_open then
            state.category_force_open[category_key] = true
        else
            state.category_force_closed[category_key] = true
        end
        if state.settings.remember_opened_categories == true then
            if type(state.settings.opened_categories) ~= 'table' then
                state.settings.opened_categories = T{}
            end
            state.settings.opened_categories[category_key] = was_open
        end
        save_settings()
    end
end

local recipe_catalog_by_key = nil
local recipe_search_catalog = nil
local rank_test_recipe_catalog = nil
local output_recipe_index = nil
local ingredient_recipe_index = nil

local function compare_recipe_entries(left, right)
    if left.craft_index ~= right.craft_index then
        return left.craft_index < right.craft_index
    end
    local left_cap = tonumber(left.recipe.cap) or 0
    local right_cap = tonumber(right.recipe.cap) or 0
    if left_cap ~= right_cap then
        return left_cap < right_cap
    end
    return (tonumber(left.recipe.id) or 0) < (tonumber(right.recipe.id) or 0)
end

local function build_recipe_catalogs()
    if recipe_search_catalog then
        return
    end

    recipe_catalog_by_key = {}
    recipe_search_catalog = {}
    rank_test_recipe_catalog = {}
    output_recipe_index = {}
    ingredient_recipe_index = {}

    for craft_index, craft_name in ipairs(CRAFT_NAMES) do
        local craft_rank_tests = rank_tests[craft_name] or {}
        for _, recipe in ipairs(CRAFTBOOK_DATA[craft_name] or {}) do
            local result_id = tonumber(recipe.result and recipe.result.id) or 0
            local entry = {
                craft_name = craft_name,
                craft_index = craft_index,
                recipe = recipe,
                result_name = tostring(
                    resources.get_name(result_id) or 'Unknown Item'
                ),
            }
            entry.search_name = string.lower(entry.result_name)
            recipe_catalog_by_key[get_bookmark_key(craft_name, recipe)] = entry
            recipe_search_catalog[#recipe_search_catalog + 1] = entry

            if craft_rank_tests[result_id] then
                rank_test_recipe_catalog[#rank_test_recipe_catalog + 1] = entry
            end
            if result_id > 0 then
                output_recipe_index[result_id] = output_recipe_index[result_id] or {}
                output_recipe_index[result_id][#output_recipe_index[result_id] + 1] = entry
            end

            local seen_ingredients = {}
            for _, ingredient in ipairs(recipe.ingredients or {}) do
                local item_id = tonumber(ingredient.id) or 0
                if item_id > 0 and not seen_ingredients[item_id] then
                    seen_ingredients[item_id] = true
                    local usage = ingredient_recipe_index[item_id]
                    if not usage then
                        usage = { recipe_count = 0, crafts = {} }
                        ingredient_recipe_index[item_id] = usage
                    end
                    usage.recipe_count = usage.recipe_count + 1
                    usage.crafts[craft_name] =
                        (usage.crafts[craft_name] or 0) + 1
                end
            end
        end
    end

    table.sort(recipe_search_catalog, function (left, right)
        if left.search_name ~= right.search_name then
            return left.search_name < right.search_name
        end
        return compare_recipe_entries(left, right)
    end)
    table.sort(rank_test_recipe_catalog, compare_recipe_entries)
    for _, entries in pairs(output_recipe_index) do
        table.sort(entries, compare_recipe_entries)
    end
end

local function get_bookmarked_recipes()
    build_recipe_catalogs()

    local bookmarked = {}
    for _, bookmark_key in ipairs(state.settings.bookmarks or {}) do
        local entry = recipe_catalog_by_key[tostring(bookmark_key)]
        if entry then
            bookmarked[#bookmarked + 1] = entry
        end
    end
    return bookmarked
end

local function get_rank_test_recipes(craft_name)
    build_recipe_catalogs()
    local recipes = {}
    for _, entry in ipairs(rank_test_recipe_catalog) do
        if entry.craft_name == craft_name then
            recipes[#recipes + 1] = entry
        end
    end
    return recipes
end

local function get_recipe_search_results(query)
    local normalized = string.lower(tostring(query or ''))
    normalized = normalized:gsub('^%s+', ''):gsub('%s+$', '')
    if normalized == '' then
        return {}, 0
    end

    local terms = {}
    for term in normalized:gmatch('[^%*]+') do
        term = term:gsub('^%s+', ''):gsub('%s+$', '')
        if term ~= '' then
            terms[#terms + 1] = term
        end
    end
    if #terms == 0 then
        return {}, 0
    end

    build_recipe_catalogs()
    local results = {}
    local total = 0
    for _, entry in ipairs(recipe_search_catalog) do
        local search_from = 1
        local matched = true
        for _, term in ipairs(terms) do
            local start_at, end_at = entry.search_name:find(term, search_from, true)
            if not start_at then
                matched = false
                break
            end
            search_from = end_at + 1
        end
        if matched then
            total = total + 1
            if #results < MAX_RECIPE_SEARCH_RESULTS then
                results[#results + 1] = entry
            end
        end
    end
    return results, total
end

local function get_recipe_rank(recipe)
    local cap = tonumber(recipe.cap) or 0
    for _, rank in ipairs(CRAFT_RANKS) do
        if cap >= rank.min and cap <= rank.max then
            return rank
        end
    end
    return nil
end

local function get_output_recipe_index()
    build_recipe_catalogs()
    return output_recipe_index
end

local function get_ingredient_recipe_index()
    build_recipe_catalogs()
    return ingredient_recipe_index
end

local ITEM_TYPE_LABELS = {
    [1] = 'General',
    [4] = 'Weapon',
    [5] = 'Armor',
    [7] = 'Usable',
    [8] = 'Crystal',
    [10] = 'Furniture',
}

local function format_recipe_crafts(craft_counts, include_counts)
    local labels = {}
    for _, craft_name in ipairs(CRAFT_NAMES) do
        local count = tonumber(craft_counts[craft_name]) or 0
        if count > 0 then
            local craft = crafts[craft_name]
            local label = craft and craft.label or craft_name
            if include_counts and count > 1 then
                label = ('%s (%d recipes)'):format(label, count)
            end
            labels[#labels + 1] = label
        end
    end
    return #labels > 0 and table.concat(labels, ', ') or 'None in Artisan'
end

local function get_item_recipe_relationships(item_id)
    local usage = get_ingredient_recipe_index()[item_id] or {
        recipe_count = 0,
        crafts = {},
    }
    local produced_by = {}
    for _, entry in ipairs(get_output_recipe_index()[item_id] or {}) do
        produced_by[entry.craft_name] =
            (produced_by[entry.craft_name] or 0) + 1
    end
    return usage, produced_by
end

local function get_recipe_variant_number(craft_name, recipe)
    local result_id = tonumber(recipe.result and recipe.result.id) or 0
    local matching_recipes = {}
    for _, entry in ipairs(get_output_recipe_index()[result_id] or {}) do
        if entry.craft_name == craft_name then
            matching_recipes[#matching_recipes + 1] = entry.recipe
        end
    end
    if #matching_recipes < 2 then
        return nil
    end
    table.sort(matching_recipes, function(left, right)
        return (tonumber(left.id) or 0) < (tonumber(right.id) or 0)
    end)
    local recipe_id = tonumber(recipe.id) or 0
    for index, matching_recipe in ipairs(matching_recipes) do
        if (tonumber(matching_recipe.id) or 0) == recipe_id then
            return index
        end
    end
    return nil
end

local function get_recipe_ingredient_summary(recipe)
    local parts = {}
    local ingredients = recipe.ingredients or {}
    local visible_count = math.min(2, #ingredients)
    for index = 1, visible_count do
        local ingredient = ingredients[index]
        local count = tonumber(ingredient.count) or 1
        local count_text = count > 1 and (' x%d'):format(count) or ''
        parts[#parts + 1] = resources.get_name(tonumber(ingredient.id) or 0) .. count_text
    end
    if #ingredients > visible_count then
        parts[#parts + 1] = '...'
    end
    return table.concat(parts, ' + ')
end

local function clear_recipe_jump(force)
    if not force and state.settings.remember_jump_location == true then
        return
    end

    state.recipe_jump_target = nil
    state.recipe_jump_category_key = nil
    state.recipe_jump_scroll_pending = false
    state.recipe_jump_highlight_active = false
end

local function jump_to_recipe(craft_name, recipe)
    local rank = get_recipe_rank(recipe)
    if not rank then
        return
    end

    if state.craftbook_craft ~= craft_name and
        state.settings.remember_opened_categories ~= true then
        collapse_craftbook_categories(craft_name, false)
    end

    local category_key = ('craftbook:%s:%s'):format(craft_name, rank.name)
    state.craftbook_craft = craft_name
    state.craftbook_open[1] = true
    state.category_force_open[category_key] = true
    state.category_force_closed[category_key] = nil
    state.recipe_jump_target = get_bookmark_key(craft_name, recipe)
    state.recipe_jump_category_key = category_key
    state.recipe_jump_scroll_pending = true
    state.recipe_jump_highlight_active = false

    if state.settings.remember_opened_categories == true then
        if type(state.settings.opened_categories) ~= 'table' then
            state.settings.opened_categories = T{}
        end
        state.settings.opened_categories[category_key] = true
        save_settings()
    end
end

local function get_recipe_jump_label(entry, id_prefix)
    local craft = crafts[entry.craft_name]
    local craft_label = craft and craft.label or entry.craft_name
    local recipe = entry.recipe
    local yield_count = tonumber(recipe.result and recipe.result.count) or 1
    return ('%s %d  |  Yield %d  |  %s##%s_%s_%s'):format(
        craft_label,
        tonumber(recipe.cap) or 0,
        yield_count,
        get_recipe_ingredient_summary(recipe),
        id_prefix,
        entry.craft_name,
        tostring(recipe.id)
    )
end

local function render_material_recipe_options(item_id)
    local entries = get_output_recipe_index()[tonumber(item_id) or 0] or {}
    if #entries == 0 then
        imgui.TextDisabled('No recipe found')
        return false
    elseif #entries == 1 then
        if imgui.MenuItem('Jump to Recipe') then
            jump_to_recipe(entries[1].craft_name, entries[1].recipe)
            return true
        end
    elseif imgui.BeginMenu('Jump to Recipe') then
        local selected = false
        for _, entry in ipairs(entries) do
            if imgui.MenuItem(get_recipe_jump_label(entry, 'Jump')) then
                jump_to_recipe(entry.craft_name, entry.recipe)
                selected = true
            end
        end
        imgui.EndMenu()
        return selected
    end
    return false
end

local function render_tracker_material_recipe_options(item_id)
    local entries = get_output_recipe_index()[tonumber(item_id) or 0] or {}
    if #entries == 0 then
        imgui.TextDisabled('No recipe found')
        return false
    elseif #entries == 1 then
        local activated = imgui.Selectable('Jump to Recipe##TrackerJump', false)
        local left_button = ImGuiMouseButton_Left or 0
        if activated or imgui.IsItemClicked(left_button) then
            state.pending_recipe_jump = entries[1]
            return true
        end
        return false
    end

    imgui.TextDisabled('Jump to Recipe')
    imgui.Separator()
    for _, entry in ipairs(entries) do
        local activated = imgui.Selectable(
            get_recipe_jump_label(entry, 'TrackerJump'),
            false
        )
        local left_button = ImGuiMouseButton_Left or 0
        if activated or imgui.IsItemClicked(left_button) then
            state.pending_recipe_jump = entry
            return true
        end
    end
    return false
end

local function render_material_context_menu(item_id, context_id, right_clicked)
    local popup_id = '##MaterialRecipe_' .. context_id
    if right_clicked and not imgui.IsPopupOpen(popup_id) then
        imgui.OpenPopup(popup_id)
        state.material_context_popup_id = popup_id
    end
    if not imgui.BeginPopup(popup_id) then
        if state.material_context_popup_id == popup_id
            and not imgui.IsPopupOpen(popup_id) then
            state.material_context_popup_id = nil
        end
        return
    end
    state.material_context_popup_id = popup_id
    render_material_recipe_options(item_id)
    imgui.EndPopup()
end

local function queue_tracker_material_context_menu(item_id, right_clicked)
    if right_clicked and state.tracker_material_popup_item_id == nil then
        local io = imgui.GetIO()
        state.tracker_material_popup_item_id = tonumber(item_id) or 0
        state.tracker_material_popup_pending = true
        state.tracker_material_popup_x = tonumber(io.MousePos.x) or 0
        state.tracker_material_popup_y = tonumber(io.MousePos.y) or 0
    end
end

local function close_tracker_material_context_menu()
    state.tracker_material_popup_item_id = nil
    state.tracker_material_popup_pending = false
end

local function render_tracker_material_context_menu()
    if state.tracker_material_popup_item_id == nil then
        return
    end

    local scale = get_ui_scale()
    if state.tracker_material_popup_pending then
        imgui.SetNextWindowPos(
            {
                state.tracker_material_popup_x,
                state.tracker_material_popup_y,
            },
            ImGuiCond_Always
        )
        imgui.SetNextWindowFocus()
    end

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoDocking,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav
    )
    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8 * scale, 6 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 3 * scale)

    local began = imgui.Begin('##ArtisanTrackerMaterialRecipe', nil, flags)
    local selected = false
    local hovered = false
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))
        selected = render_tracker_material_recipe_options(
            state.tracker_material_popup_item_id
        )
        hovered = imgui.IsWindowHovered()
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()

    local was_pending = state.tracker_material_popup_pending
    state.tracker_material_popup_pending = false
    local left_button = ImGuiMouseButton_Left or 0
    local right_button = ImGuiMouseButton_Right or 1
    local clicked_elsewhere = not was_pending
        and not hovered
        and (
            imgui.IsMouseClicked(left_button, false)
            or imgui.IsMouseClicked(right_button, false)
        )
    if selected or clicked_elsewhere then
        close_tracker_material_context_menu()
    end
end

local function render_tooltip_value(label, value)
    imgui.TextColored(COLORS.gray, label .. ':')
    imgui.SameLine(0, 5)
    imgui.TextWrapped(tostring(value):gsub('%%', '%%%%'))
end

local function render_item_tooltip(item_id)
    local right_button = ImGuiMouseButton_Right or 1
    if imgui.IsMouseDown(right_button)
        or state.material_context_popup_id ~= nil
        or state.tracker_material_popup_item_id ~= nil then
        return
    end

    local details = resources.get_item_details(item_id)
    local usage, produced_by = get_item_recipe_relationships(item_id)
    local item_type = ITEM_TYPE_LABELS[tonumber(details.item_type) or 0] or 'General'
    if item_type ~= 'Crystal' and (tonumber(usage.recipe_count) or 0) > 0 then
        item_type = 'Crafting Material'
    end

    imgui.BeginTooltip()
    imgui.PushTextWrapPos(420 * get_ui_scale())
    render_tooltip_value('Item Name', details.name)
    render_tooltip_value(
        'Game Description',
        details.description ~= '' and details.description or 'Not available'
    )
    render_tooltip_value('Item Type', item_type)
    render_tooltip_value('Used by', format_recipe_crafts(usage.crafts, false))
    render_tooltip_value(
        'Used in',
        ('%d %s'):format(
            usage.recipe_count,
            usage.recipe_count == 1 and 'recipe' or 'recipes'
        )
    )
    render_tooltip_value('Produced by', format_recipe_crafts(produced_by, true))
    imgui.PopTextWrapPos()
    imgui.EndTooltip()
end

local function render_item_icon(item_id, missing, scale, logical_size)
    local icon = resources.get_icon(item_id)
    local icon_size = logical_size or 30
    local size = { icon_size * scale, icon_size * scale }
    if icon then
        local pointer = resources.texture_pointer(icon)
        if missing then
            imgui.ImageWithBg(
                pointer,
                size,
                { 0, 0 },
                { 1, 1 },
                COLORS.missing_bg,
                COLORS.missing_tint
            )
        else
            imgui.Image(pointer, size)
        end
    else
        imgui.TextColored(missing and COLORS.red or COLORS.gray, '[?]')
    end
    local right_button = ImGuiMouseButton_Right or 1
    local right_clicked = imgui.IsItemClicked(right_button)
    if imgui.IsItemHovered() then
        render_item_tooltip(item_id)
    end
    return right_clicked
end

local function render_recipe_header(
    recipe,
    skill,
    counts,
    scale,
    craft_rank_tests,
    bookmark_key,
    bookmark_instance,
    tracker_jump_enabled
)
    local row_start = imgui.GetCursorPosX()
    local row_width = imgui.GetContentRegionAvail()
    local result_id = tonumber(recipe.result.id) or 0
    local result_icon_right_clicked = render_item_icon(
        result_id,
        false,
        scale,
        24
    )
    imgui.SameLine(0, 7 * scale)
    imgui.TextColored(get_recipe_color(recipe.cap, skill), resources.get_name(result_id))
    if imgui.IsItemHovered() then
        render_item_tooltip(result_id)
    end
    if tracker_jump_enabled then
        local right_button = ImGuiMouseButton_Right or 1
        queue_tracker_material_context_menu(
            result_id,
            result_icon_right_clicked or imgui.IsItemClicked(right_button)
        )
    end
    local result_count = tonumber(recipe.result.count) or 1
    if result_count > 1 then
        imgui.SameLine(0, 6 * scale)
        imgui.Text(('x%d'):format(result_count))
    end
    imgui.SameLine(0, 8 * scale)
    imgui.Text(('[Cap %d]'):format(recipe.cap))
    imgui.SameLine(0, 7 * scale)
    imgui.Text('-')
    imgui.SameLine(0, 6 * scale)

    local crystal_id = tonumber(recipe.crystal) or 0
    local crystal_owned = tonumber(counts[crystal_id]) or 0
    render_item_icon(
        crystal_id,
        crystal_owned < 1,
        scale,
        14
    )
    imgui.SameLine(0, 5 * scale)
    imgui.Text(resources.get_name(crystal_id))
    if imgui.IsItemHovered() then
        render_item_tooltip(crystal_id)
    end

    local edge_gap = 4 * scale
    local right_edge = row_start + row_width - edge_gap
    local craft_count_label = nil
    local craft_count_width = 0
    if state.settings.show_recipe_craft_count ~= false then
        craft_count_label = ('[%d]'):format(matcher.get_max_crafts(recipe, counts))
        craft_count_width = imgui.CalcTextSize(craft_count_label)
    end

    if bookmark_key then
        local bookmark_label = 'Bookmark'
        local bookmark_width = imgui.CalcTextSize(bookmark_label)
            + imgui.GetTextLineHeight()
            + (5 * scale)
        local bookmark_right = right_edge
        if craft_count_label then
            bookmark_right = bookmark_right - craft_count_width - (12 * scale)
        end
        imgui.SameLine()
        imgui.SetCursorPosX(
            math.max(row_start, bookmark_right - bookmark_width)
        )
        imgui.Text(bookmark_label)
        imgui.SameLine(0, 5 * scale)
        local bookmarked = { is_recipe_bookmarked(bookmark_key) }
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
        local checkbox_id = ('##Bookmark_%s_%s'):format(
            bookmark_instance or 'recipe',
            bookmark_key
        )
        if imgui.Checkbox(checkbox_id, bookmarked) then
            set_recipe_bookmarked(bookmark_key, bookmarked[1])
        end
        imgui.PopStyleVar()
    end

    if craft_count_label then
        imgui.SameLine()
        imgui.SetCursorPosX(math.max(row_start, right_edge - craft_count_width))
        imgui.Text(craft_count_label)
    end

    local rank_test = (craft_rank_tests or {})[result_id]
    if rank_test then
        imgui.Indent(31 * scale)
        imgui.TextColored(COLORS.heading, 'RANK TEST')
        imgui.SameLine(0, 8 * scale)
        imgui.Text(rank_test.rank)
        imgui.Unindent(31 * scale)
    end
end

local function render_subcrafts(recipe, player, scale)
    local requirements = recipe.subcrafts or {}
    if #requirements == 0 then
        return
    end

    imgui.TextDisabled('SUBCRAFT')
    imgui.SameLine(0, 7 * scale)
    imgui.TextDisabled('-')
    for index, requirement in ipairs(requirements) do
        local craft = crafts[requirement.craft]
        local label = craft and craft.label or tostring(requirement.craft)
        local cap = tonumber(requirement.cap) or 0
        local skill = get_craft_skill(player, requirement.craft)
        imgui.SameLine(0, 7 * scale)
        imgui.TextColored(
            skill >= cap and COLORS.green or COLORS.red,
            ('%s %d'):format(label, cap)
        )
        if index < #requirements then
            imgui.SameLine(0, 2 * scale)
            imgui.TextDisabled(',')
        end
    end
end

local function render_craft_button(label, id, size, selected, enabled)
    local pushed_colors = 0
    if selected then
        imgui.PushStyleColor(ImGuiCol_Text, COLORS.heading)
        imgui.PushStyleColor(ImGuiCol_Button, COLORS.button_selected)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.button_selected_hovered)
        imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.button_selected_active)
        pushed_colors = 4
    elseif not enabled then
        imgui.PushStyleColor(ImGuiCol_Text, COLORS.gray)
        imgui.PushStyleColor(ImGuiCol_Button, COLORS.child_bg)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.child_bg)
        imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.child_bg)
        pushed_colors = 4
    end

    local clicked = imgui.Button(label .. '##' .. id, size)
    if pushed_colors > 0 then
        imgui.PopStyleColor(pushed_colors)
    end
    return clicked and enabled
end

local function render_craft_selector(scale)
    local spacing = 7 * scale
    local button_width = math.max(
        90 * scale,
        (imgui.GetContentRegionAvail() - (spacing * 3)) / 4
    )
    for row = 1, 2 do
        for column = 1, 4 do
            local index = ((row - 1) * 4) + column
            local craft_name = CRAFT_NAMES[index]
            local craft = crafts[craft_name]
            local available = CRAFTBOOK_DATA[craft_name] ~= nil
            local selected = available and state.craftbook_craft == craft_name
            if render_craft_button(
                string.upper(craft.label),
                'CraftbookCraft_' .. craft_name,
                { button_width, 0 },
                selected,
                available
            ) then
                if state.craftbook_craft ~= craft_name and
                    state.settings.remember_opened_categories ~= true then
                    collapse_craftbook_categories(craft_name, false)
                end
                if state.craftbook_craft ~= craft_name then
                    clear_recipe_jump()
                end
                state.craftbook_craft = craft_name
            end
            if column < 4 then
                imgui.SameLine(0, spacing)
            end
        end
    end
end

local function render_requirements(recipe, counts, scale)
    local item_ids, requirements = get_requirement_ids(recipe)
    imgui.Columns(2, '##requirements_' .. tostring(recipe.id), false)
    imgui.SetColumnWidth(0, 235 * scale)
    for _, item_id in ipairs(item_ids) do
        imgui.TextColored(
            COLORS.gray,
            ('%s x%d'):format(resources.get_name(item_id), requirements[item_id])
        )
        if imgui.IsItemHovered() then
            render_item_tooltip(item_id)
        end
        local right_button = ImGuiMouseButton_Right or 1
        queue_tracker_material_context_menu(
            item_id,
            imgui.IsItemClicked(right_button)
        )
        imgui.NextColumn()
        local owned_label = ('Own: %d'):format(tonumber(counts[item_id]) or 0)
        local text_width = imgui.CalcTextSize(owned_label)
        local cursor_x = imgui.GetCursorPosX()
        local available_width = imgui.GetColumnWidth()
        imgui.SetCursorPosX(
            cursor_x + math.max(0, available_width - text_width - (12 * scale))
        )
        imgui.Text(owned_label)
        queue_tracker_material_context_menu(
            item_id,
            imgui.IsItemClicked(right_button)
        )
        imgui.NextColumn()
    end
    imgui.Columns(1)
end

local function render_recipe(entry, skill, counts, scale, craft_rank_tests)
    local recipe = entry.recipe
    render_recipe_header(recipe, skill, counts, scale, craft_rank_tests, nil, nil, true)
    imgui.Indent(31 * scale)
    render_requirements(recipe, counts, scale)
    imgui.Unindent(31 * scale)
    imgui.Separator()
end

local function get_tracker_width(available_by_craft, scale)
    local longest_header = 0
    for _, available in pairs(available_by_craft) do
        for _, entry in ipairs(available) do
            local recipe = entry.recipe
            local result_count = tonumber(recipe.result.count) or 1
            local yield_text = result_count > 1 and (' x%d'):format(result_count) or ''
            local craft_count_text =
                state.settings.show_recipe_craft_count ~= false
                and (' [%d]'):format(tonumber(entry.crafts) or 0)
                or ''
            local header = ('%s%s [Cap %d] - %s%s'):format(
                resources.get_name(recipe.result.id),
                yield_text,
                tonumber(recipe.cap) or 0,
                resources.get_name(recipe.crystal),
                craft_count_text
            )
            longest_header = math.max(longest_header, #header)
        end
    end
    local logical_width = math.max(385, math.min(520, 70 + (longest_header * 6.6)))
    return logical_width * scale
end

local function render_craftable_recipe_list(
    craft_name,
    available,
    skill,
    counts,
    scale
)
    local craft = crafts[craft_name]
    local label = ('%-12s RECIPES  SKILL %3d  (%d)##Craftable%s'):format(
        string.upper(craft.label),
        skill,
        #available,
        craft_name
    )
    if not render_category_header(label, 'tracker:' .. craft_name, true) then
        return
    end

    if #available == 0 then
        imgui.TextDisabled('-')
        return
    end

    local use_scroll = #available > MAX_VISIBLE_CRAFTABLE_RECIPES
    if use_scroll then
        imgui.BeginChild(
            '##CraftableRecipeScroll_' .. craft_name,
            { 0, 230 * scale },
            0,
            ImGuiWindowFlags_AlwaysVerticalScrollbar or 0
        )
    end
    for _, entry in ipairs(available) do
        render_recipe(entry, skill, counts, scale, rank_tests[craft_name])
    end
    if use_scroll then
        imgui.EndChild()
    end
end

local function get_ranked_recipes(skill, recipe_list)
    local groups = {}
    for rank_index, rank in ipairs(CRAFT_RANKS) do
        groups[rank_index] = { rank = rank, recipes = {} }
    end
    for _, recipe in ipairs(recipe_list or {}) do
        local cap = tonumber(recipe.cap) or 0
        for rank_index, rank in ipairs(CRAFT_RANKS) do
            if cap >= rank.min and cap <= rank.max then
                local group = groups[rank_index]
                group.recipes[#group.recipes + 1] = recipe
                break
            end
        end
    end
    for _, group in ipairs(groups) do
        table.sort(group.recipes, function (left, right)
            local left_gap = math.abs((tonumber(left.cap) or 0) - skill)
            local right_gap = math.abs((tonumber(right.cap) or 0) - skill)
            if left_gap ~= right_gap then
                return left_gap < right_gap
            end
            if left.cap ~= right.cap then
                return left.cap < right.cap
            end
            return left.id < right.id
        end)
    end
    return groups
end

local function render_material_grid(
    recipe,
    counts,
    scale,
    required_key_item_name,
    has_required_key_item_value,
    craft_name,
    recipe_instance
)
    local requirements = matcher.get_requirements(recipe)
    imgui.TextDisabled('MATERIALS')
    local variant_number = get_recipe_variant_number(craft_name, recipe)
    if variant_number then
        imgui.SameLine(0, 7 * scale)
        imgui.TextDisabled('-')
        imgui.SameLine(0, 7 * scale)
        imgui.Text(('VARIANT #%d'):format(variant_number))
    end
    if required_key_item_name then
        imgui.SameLine(0, 7 * scale)
        imgui.TextDisabled('-')
        imgui.SameLine(0, 7 * scale)
        imgui.TextColored(
            has_required_key_item_value and COLORS.green or COLORS.red,
            ('Required: %s'):format(required_key_item_name)
        )
    end
    local total_slots = 0
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        total_slots = total_slots + (tonumber(ingredient.count) or 0)
    end

    local grid_index = 0
    local used = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local item_id = tonumber(ingredient.id) or 0
        local required = tonumber(requirements[item_id]) or 0
        local owned = tonumber(counts[item_id]) or 0
        local amount = tonumber(ingredient.count) or 0
        for _ = 1, amount do
            used[item_id] = (used[item_id] or 0) + 1
            grid_index = grid_index + 1
            local right_clicked = render_item_icon(
                item_id,
                used[item_id] > owned,
                scale
            )
            render_material_context_menu(
                item_id,
                ('craftbook_%s_%s_%s_%s_%d'):format(
                    recipe_instance or 'recipe',
                    craft_name,
                    tostring(recipe.id),
                    item_id,
                    used[item_id]
                ),
                right_clicked
            )
            if grid_index < total_slots and grid_index % 8 ~= 0 then
                imgui.SameLine(0, 5 * scale)
            end
        end
    end
end

local function render_craftbook_recipe(
    recipe,
    player,
    skill,
    counts,
    scale,
    craft_rank_tests,
    craft_name,
    bookmark_instance
)
    local recipe_key = get_bookmark_key(craft_name, recipe)
    local is_catalog_target = bookmark_instance == 'catalog'
        and state.recipe_jump_target == recipe_key
    local recipe_start_x, recipe_start_y = imgui.GetCursorScreenPos()
    local recipe_width = imgui.GetContentRegionAvail()
    render_recipe_header(
        recipe,
        skill,
        counts,
        scale,
        craft_rank_tests,
        get_bookmark_key(craft_name, recipe),
        bookmark_instance
    )

    local key_item_id = tonumber(recipe.key_item) or 0
    local required_key_item_name = nil
    local has_key_item = true
    if key_item_id ~= 0 then
        has_key_item = has_required_key_item(player, recipe)
        required_key_item_name = key_item_names[key_item_id]
            or resources.get_key_item_name(key_item_id)
    end
    imgui.Indent(31 * scale)
    render_subcrafts(recipe, player, scale)
    render_material_grid(
        recipe,
        counts,
        scale,
        required_key_item_name,
        has_key_item,
        craft_name,
        bookmark_instance
    )
    imgui.Unindent(31 * scale)
    imgui.Separator()
    local _, recipe_end_y = imgui.GetCursorScreenPos()
    local just_scrolled = false
    if is_catalog_target and state.recipe_jump_scroll_pending then
        imgui.SetScrollHereY(0.5)
        state.recipe_jump_scroll_pending = false
        state.recipe_jump_highlight_active = true
        just_scrolled = true
    end
    if is_catalog_target and state.recipe_jump_highlight_active and not just_scrolled then
        local outline_min = {
            recipe_start_x + 1,
            recipe_start_y - (4 * scale),
        }
        local outline_max = {
            recipe_start_x + recipe_width - (2 * scale),
            recipe_end_y - (2 * scale),
        }
        if imgui.IsRectVisible(outline_min, outline_max) then
            local draw_list = imgui.GetWindowDrawList()
            draw_list:AddRect(
                outline_min,
                outline_max,
                imgui.GetColorU32(COLORS.heading),
                5 * scale,
                0,
                2
            )
        else
            clear_recipe_jump()
        end
    end
end

local function render_recipe_search(scale)
    imgui.SetNextItemWidth(imgui.GetContentRegionAvail())
    imgui.InputTextWithHint(
        '##CraftbookRecipeSearch',
        'Search recipes...',
        state.recipe_search,
        128
    )

    local results, total = get_recipe_search_results(state.recipe_search[1])
    if tostring(state.recipe_search[1] or ''):match('^%s*$') then
        return
    end
    if total == 0 then
        imgui.TextDisabled('No matching recipes')
        return
    end

    local visible_rows = math.min(6, #results)
    imgui.BeginChild(
        '##CraftbookRecipeSearchResults',
        { 0, visible_rows * (28 * scale) },
        0,
        (#results > visible_rows and ImGuiWindowFlags_AlwaysVerticalScrollbar or 0)
    )
    for _, entry in ipairs(results) do
        local recipe = entry.recipe
        local result_id = tonumber(recipe.result and recipe.result.id) or 0
        render_item_icon(result_id, false, scale, 18)
        imgui.SameLine(0, 7 * scale)
        local craft = crafts[entry.craft_name]
        local craft_label = craft and craft.label or entry.craft_name
        local label = ('%s  |  %s  |  Cap %d##RecipeSearch_%s_%s'):format(
            entry.result_name,
            craft_label,
            tonumber(recipe.cap) or 0,
            entry.craft_name,
            tostring(recipe.id)
        )
        if imgui.Selectable(label, false, 0, { 0, 20 * scale }) then
            state.pending_recipe_jump = entry
            state.recipe_search[1] = ''
        end
    end
    imgui.EndChild()
    if total > #results then
        imgui.TextDisabled(
            ('Showing first %d of %d matches'):format(#results, total)
        )
    end
end

local function render_recipe_window()
    local player = get_player()
    if not player or player:GetLoginStatus() ~= 2 or not state.visible[1] then
        state.tracker_was_visible = false
        close_tracker_material_context_menu()
        return
    end

    if not state.tracker_was_visible then
        if state.settings.remember_opened_categories ~= true then
            collapse_tracker_categories()
        end
        state.tracker_was_visible = true
    end

    local scale = get_ui_scale()
    local counts = inventory.get_counts(false, get_material_containers())
    local available_by_craft = {}
    local total_available = 0
    for _, craft_name in ipairs(CRAFT_NAMES) do
        local available = get_available_recipes(
            player,
            counts,
            craft_name,
            CRAFTBOOK_DATA[craft_name]
        )
        available_by_craft[craft_name] = available
        total_available = total_available + #available
    end
    local tracker_width = get_tracker_width(available_by_craft, scale)
    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoDocking,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoFocusOnAppearing
    )
    if state.settings.locked or is_titlebar_help_hovered('artisan') then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove)
    end
    if not state.position_applied then
        imgui.SetNextWindowPos(
            { state.settings.position_x, state.settings.position_y },
            ImGuiCond_Always
        )
        state.position_applied = true
    end
    imgui.SetNextWindowSizeConstraints(
        { tracker_width, 0 },
        { tracker_width, 650 * scale }
    )

    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 7 * scale, 10 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0)
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 7 * scale, 3 * scale })

    local began = imgui.Begin('Artisan##ArtisanTracker', state.visible, flags)
    local content_ok, content_error = true, nil
    local font_pushed = false
    if began then
        draw_titlebar_help_button('artisan', scale)
        draw_main_titlebar_version(scale)
        font_pushed = push_scaled_font(scale)
        content_ok, content_error = pcall(function ()
            local window_x, window_y = imgui.GetWindowPos()
            state.settings.position_x = window_x
            state.settings.position_y = window_y

            local button_width = 150 * scale
            if render_craft_button(
                'OPEN CRAFTBOOK',
                'OpenCraftbook',
                { button_width, 0 },
                state.craftbook_open[1],
                true
            ) then
                state.craftbook_open[1] = not state.craftbook_open[1]
            end
            imgui.SameLine(0, 7 * scale)
            if render_craft_button(
                'OPEN FILTERS',
                'OpenFilters',
                { button_width, 0 },
                state.filters_open[1],
                true
            ) then
                state.filters_open[1] = not state.filters_open[1]
            end
            imgui.Spacing()
            render_section_bar('CRAFT LEVELS')
            render_craft_levels(player, scale)
            imgui.Spacing()
            render_section_bar('CRAFTABLE RECIPES')
            imgui.TextColored(COLORS.gray, 'CRAFTABLE')
            imgui.SameLine()
            imgui.TextColored(COLORS.white, tostring(total_available))
            imgui.Spacing()
            for _, craft_name in ipairs(CRAFT_NAMES) do
                local craft_recipes = available_by_craft[craft_name]
                if #craft_recipes > 0 or state.settings.show_empty_crafts ~= false then
                    render_craftable_recipe_list(
                        craft_name,
                        craft_recipes,
                        get_craft_skill(player, craft_name),
                        counts,
                        scale
                    )
                end
            end
        end)
    end
    if font_pushed then
        pcall(function () imgui.PopFont() end)
    end
    imgui.End()
    imgui.PopStyleVar(4)
    pop_artisan_theme()

    if not content_ok then
        error(content_error)
    end

    if state.settings.visible ~= state.visible[1] then
        state.settings.visible = state.visible[1]
        settings.save()
    end
end

local function minimize_artisan_windows()
    if state.settings.close_all_windows_with_artisan ~= false then
        state.craftbook_open[1] = false
        state.filters_open[1] = false
        state.settings_open[1] = false
        state.colors_open[1] = false
        state.help_open[1] = false
    end

    if state.settings.launcher_position_initialized ~= true then
        state.settings.launcher_position_x = state.settings.position_x
        state.settings.launcher_position_y = state.settings.position_y
        state.settings.launcher_position_initialized = true
        state.launcher_position_applied = false
        save_settings()
    end
end

local function render_launcher_window()
    if state.settings.launcher_position_initialized ~= true then
        state.settings.launcher_position_x = state.settings.position_x
        state.settings.launcher_position_y = state.settings.position_y
        state.settings.launcher_position_initialized = true
        state.launcher_position_applied = false
        save_settings()
    end

    local scale = math.max(
        0.75,
        math.min(3.0, tonumber(state.settings.launcher_scale) or default_settings.launcher_scale)
    )
    if not state.launcher_position_applied then
        imgui.SetNextWindowPos(
            {
                tonumber(state.settings.launcher_position_x) or 80,
                tonumber(state.settings.launcher_position_y) or 180,
            },
            ImGuiCond_Always
        )
        state.launcher_position_applied = true
    end

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoDocking,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoFocusOnAppearing
    )
    local rounded_button = state.settings.artisan_button_rounded == true
    push_artisan_theme(scale)
    imgui.PushStyleVar(
        ImGuiStyleVar_WindowRounding,
        rounded_button and (12 * scale) or (3 * scale)
    )
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 5 * scale, 5 * scale })

    local began = imgui.Begin('Artisan Launcher##ArtisanLauncher', nil, flags)
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))
        imgui.PushStyleVar(
            ImGuiStyleVar_FrameRounding,
            rounded_button and (imgui.GetFrameHeight() / 2) or (3 * scale)
        )
        local launcher_button_size = rounded_button
            and { 100 * scale, 0 }
            or { 70 * scale, 70 * scale }
        local clicked = imgui.Button(
            'ARTISAN##RestoreArtisan',
            launcher_button_size
        )
        imgui.PopStyleVar()
        local left_button = ImGuiMouseButton_Left or 0
        if imgui.IsItemActive() and imgui.IsMouseDragging(left_button, 3 * scale) then
            state.launcher_dragged = true
            local io = imgui.GetIO()
            local delta_x = tonumber(io.MouseDelta.x) or 0
            local delta_y = tonumber(io.MouseDelta.y) or 0
            if delta_x ~= 0 or delta_y ~= 0 then
                local window_x, window_y = imgui.GetWindowPos()
                local next_x = window_x + delta_x
                local next_y = window_y + delta_y
                imgui.SetWindowPos({ next_x, next_y }, ImGuiCond_Always)
                state.settings.launcher_position_x = next_x
                state.settings.launcher_position_y = next_y
            end
        end

        if not imgui.IsMouseDown(left_button) and state.launcher_dragged then
            state.launcher_dragged = false
            save_settings()
        elseif clicked then
            state.visible[1] = not state.visible[1]
            state.settings.visible = state.visible[1]
            save_settings()
        end
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()
end

local function render_craftbook_window()
    if not state.craftbook_open[1] then
        state.craftbook_was_open = false
        clear_recipe_jump()
        return
    end

    if not state.craftbook_was_open then
        if state.settings.remember_opened_categories ~= true
            and not state.recipe_jump_scroll_pending then
            collapse_craftbook_categories(state.craftbook_craft, true)
        end
        state.craftbook_was_open = true
    end

    local player = get_player()
    if not player or player:GetLoginStatus() ~= 2 then
        return
    end

    local scale = get_ui_scale()
    local io = imgui.GetIO()
    local display_width = tonumber(io.DisplaySize.x) or 1920
    local display_height = tonumber(io.DisplaySize.y) or 1080
    local book_width = math.min(540 * scale, display_width * 0.80)
    local desired_book_height = (
        CRAFTBOOK_CHROME_HEIGHT +
        (CRAFTBOOK_VISIBLE_RECIPE_TARGET * CRAFTBOOK_TYPICAL_RECIPE_HEIGHT)
    ) * scale
    local book_height = math.min(desired_book_height, display_height * 0.90)
    if not state.craftbook_position_applied then
        local desired_x = state.settings.position_x + (390 * scale)
        local desired_y = state.settings.position_y
        imgui.SetNextWindowPos(
            {
                math.max(0, math.min(desired_x, display_width - book_width - 12)),
                math.max(0, math.min(desired_y, display_height - book_height - 12)),
            },
            ImGuiCond_Always
        )
        state.craftbook_position_applied = true
    end
    imgui.SetNextWindowSize({ book_width, book_height }, ImGuiCond_Always)

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoDocking,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoFocusOnAppearing
    )
    if is_titlebar_help_hovered('craftbook') then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove)
    end
    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 15 * scale, 10 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0)
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 7 * scale, 4 * scale })

    local began = imgui.Begin('Craftbook##Craftbook', state.craftbook_open, flags)
    local content_ok, content_error = true, nil
    local font_pushed = false
    if began then
        draw_titlebar_help_button('craftbook', scale)
        font_pushed = push_scaled_font(scale)
        content_ok, content_error = pcall(function ()
            local selected_craft_name = state.craftbook_craft
            local selected_craft = crafts[selected_craft_name] or crafts.smithing
            local selected_recipes = CRAFTBOOK_DATA[selected_craft_name]
                or CRAFTBOOK_DATA.smithing
            local skill = get_craft_skill(player, selected_craft_name)
            local counts = inventory.get_counts(false, get_material_containers())
            local groups = get_ranked_recipes(skill, selected_recipes)
            local bookmarked_recipes = get_bookmarked_recipes()
            local rank_test_recipes = get_rank_test_recipes(selected_craft_name)

            render_craft_selector(scale)
            imgui.Spacing()

            imgui.BeginChild(
                '##CraftbookScroll',
                { 0, book_height - (CRAFTBOOK_CHROME_HEIGHT * scale) },
                0,
                ImGuiWindowFlags_AlwaysVerticalScrollbar or 0
            )
            render_recipe_search(scale)
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            local bookmark_label = ('BOOKMARKED RECIPES  (%d)###CraftbookBookmarks'):
                format(#bookmarked_recipes)
            if render_category_header(bookmark_label, 'craftbook:bookmarks') then
                if #bookmarked_recipes == 0 then
                    imgui.TextDisabled('-')
                else
                    for _, entry in ipairs(bookmarked_recipes) do
                        local bookmarked_craft = entry.craft_name
                        render_craftbook_recipe(
                            entry.recipe,
                            player,
                            get_craft_skill(player, bookmarked_craft),
                            counts,
                            scale,
                            rank_tests[bookmarked_craft],
                            bookmarked_craft,
                            'saved'
                        )
                    end
                end
            end
            imgui.Spacing()

            local rank_test_label =
                ('RANK TEST RECIPES  (%d)###CraftbookRankTests_%s'):
                    format(#rank_test_recipes, selected_craft_name)
            local rank_test_category_key =
                ('craftbook:%s:rank_tests'):format(selected_craft_name)
            if render_category_header(
                rank_test_label,
                rank_test_category_key
            ) then
                for _, entry in ipairs(rank_test_recipes) do
                    local rank_test_craft = entry.craft_name
                    render_craftbook_recipe(
                        entry.recipe,
                        player,
                        get_craft_skill(player, rank_test_craft),
                        counts,
                        scale,
                        rank_tests[rank_test_craft],
                        rank_test_craft,
                        'rank_test_' .. rank_test_craft
                    )
                end
            end
            imgui.Spacing()

            local craft_line_x = imgui.GetCursorPosX()
            imgui.TextColored(COLORS.heading, string.upper(selected_craft.label))
            imgui.SameLine()
            imgui.SetCursorPosX(craft_line_x + (130 * scale))
            imgui.TextColored(COLORS.gray, 'SKILL')
            imgui.SameLine()
            imgui.TextColored(COLORS.white, tostring(skill))
            imgui.Spacing()

            for _, group in ipairs(groups) do
                if #group.recipes > 0 then
                    local level_range = ('%d-%d'):format(
                        group.rank.min,
                        group.rank.max
                    )
                    local label = ('%-10s  %-7s  (%d)##Craftbook%s'):format(
                        group.rank.name,
                        level_range,
                        #group.recipes,
                        group.rank.name
                    )
                    local rank_category_key = ('craftbook:%s:%s'):
                        format(selected_craft_name, group.rank.name)
                    local rank_open = render_category_header(label, rank_category_key)
                    if not rank_open and
                        state.recipe_jump_category_key == rank_category_key then
                        clear_recipe_jump()
                    end
                    if rank_open then
                        for _, recipe in ipairs(group.recipes) do
                            render_craftbook_recipe(
                                recipe,
                                player,
                                skill,
                                counts,
                                scale,
                                rank_tests[selected_craft_name],
                                selected_craft_name,
                                'catalog'
                            )
                        end
                    end
                end
            end
            imgui.EndChild()
        end)
    end
    if font_pushed then
        pcall(function () imgui.PopFont() end)
    end
    imgui.End()
    imgui.PopStyleVar(4)
    pop_artisan_theme()

    if not content_ok then
        error(content_error)
    end
end

local function render_filters_window()
    if not state.filters_open[1] then
        return
    end

    local scale = get_ui_scale()
    if not state.filters_position_applied then
        imgui.SetNextWindowPos(
            {
                (tonumber(state.settings.position_x) or 80) + (170 * scale),
                (tonumber(state.settings.position_y) or 180) + (45 * scale),
            },
            ImGuiCond_Always
        )
        state.filters_position_applied = true
    end
    imgui.SetNextWindowSizeConstraints(
        { 430 * scale, 0 },
        { 540 * scale, 600 * scale }
    )

    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 14 * scale, 12 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8 * scale, 5 * scale })

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoDocking,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings
    )
    local began = imgui.Begin('Filters##ArtisanFilters', state.filters_open, flags)
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))
        render_section_bar('INCLUDE MATERIALS FROM')

        imgui.Columns(2, '##MaterialSourceColumns', false)
        imgui.SetColumnWidth(0, 205 * scale)
        for column = 1, 2 do
            for _, source in ipairs(MATERIAL_SOURCES) do
                if (column == 2) == (source.wardrobe == true) then
                    local enabled = { state.settings[source.setting] ~= false }
                    if imgui.Checkbox(source.label, enabled) then
                        state.settings[source.setting] = enabled[1]
                        inventory.invalidate()
                        save_settings()
                    end
                end
            end
            if column == 1 then
                imgui.NextColumn()
            end
        end
        imgui.Columns(1)
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(3)
    pop_artisan_theme()
end

local function clamp_number(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function render_display_slider(options)
    local scale = options.scale
    local slider_value = { options.value }
    imgui.SetNextItemWidth(280 * scale)
    local slider_changed
    if options.integer then
        slider_changed = imgui.SliderInt(
            '##' .. options.id .. 'Slider',
            slider_value,
            options.minimum,
            options.maximum,
            options.slider_format,
            ImGuiSliderFlags_AlwaysClamp or 0
        )
    else
        slider_changed = imgui.SliderFloat(
            '##' .. options.id .. 'Slider',
            slider_value,
            options.minimum,
            options.maximum,
            options.slider_format,
            ImGuiSliderFlags_AlwaysClamp or 0
        )
    end
    local finished_editing = imgui.IsItemDeactivatedAfterEdit()
    local changed_value = nil
    if slider_changed then
        if options.integer then
            changed_value = math.floor(slider_value[1] + 0.5)
        else
            changed_value =
                math.floor((slider_value[1] / options.step) + 0.5) * options.step
        end
        changed_value = clamp_number(
            changed_value,
            options.minimum,
            options.maximum
        )
    end

    imgui.SameLine(0, imgui.GetStyle().ItemInnerSpacing.x)
    imgui.AlignTextToFramePadding()
    imgui.Text(options.label)
    return changed_value, finished_editing
end

local function render_settings_window()
    if not state.settings_open[1] then
        if state.pending_ui_scale ~= nil then
            state.settings.scale = state.pending_ui_scale
            state.pending_ui_scale = nil
            save_settings()
        end
        return
    end

    local scale = get_ui_scale()
    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 14 * scale, 12 * scale })

    local flags = bit.bor(WINDOW_FLAGS, ImGuiWindowFlags_AlwaysAutoResize or 0)
    if is_titlebar_help_hovered('settings') then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove)
    end
    local began = imgui.Begin('Artisan Settings', state.settings_open, flags)
    if began then
        draw_titlebar_help_button('settings', scale)
        imgui.PushFont(nil, 13 * scale)
        render_section_bar('DISPLAY')

        if render_craft_button(
            'Window Color Theme',
            'CustomizeColors',
            { 180 * scale, 0 },
            state.colors_open[1],
            true
        ) then
            state.colors_open[1] = not state.colors_open[1]
        end

        local rounded_button = state.settings.artisan_button_rounded == true
        local shape_spacing = 6 * scale
        local shape_button_width = ((280 * scale) - shape_spacing) / 2
        if render_craft_button(
            'Square',
            'ArtisanButtonShapeBox',
            { shape_button_width, 0 },
            not rounded_button,
            true
        ) then
            state.settings.artisan_button_rounded = false
            save_settings()
        end
        imgui.SameLine(0, shape_spacing)
        if render_craft_button(
            'Rectangle',
            'ArtisanButtonShapeRounded',
            { shape_button_width, 0 },
            rounded_button,
            true
        ) then
            state.settings.artisan_button_rounded = true
            save_settings()
        end
        imgui.SameLine(0, imgui.GetStyle().ItemInnerSpacing.x)
        imgui.AlignTextToFramePadding()
        imgui.Text('Artisan Button Shape')

        local window_opacity = render_display_slider({
            key = 'window_opacity',
            id = 'WindowOpacity',
            label = 'Window opacity',
            value = math.floor(
                ((tonumber(state.settings.window_opacity) or default_settings.window_opacity) * 100) + 0.5
            ),
            minimum = 1,
            maximum = 100,
            integer = true,
            slider_format = '%d%%',
            scale = scale,
        })
        if window_opacity then
            state.settings.window_opacity = window_opacity / 100
            save_settings()
        end

        local ui_scale, ui_scale_finished = render_display_slider({
            key = 'ui_scale',
            id = 'GlobalUiScale',
            label = 'Global UI scale',
            value = state.pending_ui_scale or
                tonumber(state.settings.scale) or
                default_settings.scale,
            minimum = 0.75,
            maximum = 3.0,
            step = 0.05,
            slider_format = '%.2fx',
            scale = scale,
        })
        if ui_scale then
            state.pending_ui_scale = ui_scale
        end
        if ui_scale_finished and state.pending_ui_scale ~= nil then
            state.settings.scale = state.pending_ui_scale
            state.pending_ui_scale = nil
            save_settings()
        end

        local launcher_scale = render_display_slider({
            key = 'launcher_scale',
            id = 'ArtisanButtonScale',
            label = 'Artisan Button Scale',
            value = tonumber(state.settings.launcher_scale) or default_settings.launcher_scale,
            minimum = 0.75,
            maximum = 3.0,
            step = 0.05,
            slider_format = '%.2fx',
            scale = scale,
        })
        if launcher_scale then
            state.settings.launcher_scale = launcher_scale
            save_settings()
        end

        imgui.Spacing()
        render_section_bar('FUNCTIONALITY')

        if imgui.Button('Clear bookmarks', { 150 * scale, 0 }) then
            state.settings.bookmarks = T{}
            save_settings()
        end

        local show_artisan_button = {
            state.settings.show_artisan_button ~= false
        }
        if imgui.Checkbox('Show Artisan button', show_artisan_button) then
            state.settings.show_artisan_button = show_artisan_button[1]
            save_settings()
        end

        local show_recipe_craft_count = {
            state.settings.show_recipe_craft_count ~= false
        }
        if imgui.Checkbox('Show recipe craft count', show_recipe_craft_count) then
            state.settings.show_recipe_craft_count = show_recipe_craft_count[1]
            save_settings()
        end

        local show_empty_crafts = { state.settings.show_empty_crafts ~= false }
        if imgui.Checkbox('Show empty craft sections', show_empty_crafts) then
            state.settings.show_empty_crafts = show_empty_crafts[1]
            save_settings()
        end

        local close_windows_separately = {
            state.settings.close_all_windows_with_artisan == false
        }
        if imgui.Checkbox('Close windows separately', close_windows_separately) then
            state.settings.close_all_windows_with_artisan = not close_windows_separately[1]
            save_settings()
        end

        local remember_opened_categories = {
            state.settings.remember_opened_categories == true
        }
        if imgui.Checkbox('Remember opened categories', remember_opened_categories) then
            state.settings.remember_opened_categories = remember_opened_categories[1]
            if remember_opened_categories[1] then
                state.settings.opened_categories = T{}
                for category_key, opened in pairs(state.category_open) do
                    state.settings.opened_categories[category_key] = opened == true
                end
            end
            save_settings()
        end

        local remember_jump_location = {
            state.settings.remember_jump_location == true
        }
        if imgui.Checkbox('Remember Jump to Recipe Location', remember_jump_location) then
            state.settings.remember_jump_location = remember_jump_location[1]
            if not remember_jump_location[1] then
                clear_recipe_jump(true)
            end
            save_settings()
        end

        imgui.Spacing()
        render_section_bar('RECIPE DIFFICULTY')
        imgui.TextColored(
            COLORS.green,
            ('Easy: recipe is +%d to +%d levels above your skill.'):format(
                state.settings.useful_min,
                state.settings.useful_max
            )
        )
        imgui.TextColored(
            COLORS.red,
            ('Difficult: recipe is +%d to +%d levels above your skill.'):format(
                state.settings.risky_min,
                state.settings.risky_max
            )
        )
        imgui.TextColored(
            COLORS.yellow,
            ('HQ: your skill is +%d or more above the recipe cap.'):format(
                state.settings.hq1
            )
        )
        imgui.TextColored(COLORS.white, 'Standard: all remaining craftable recipes.')
        imgui.Spacing()

        local useful_min = { state.settings.useful_min }
        local useful_max = { state.settings.useful_max }
        local risky_min = { state.settings.risky_min }
        imgui.SetNextItemWidth(220 * scale)
        if imgui.SliderInt('Easy Min', useful_min, 1, state.settings.useful_max, '+%d') then
            state.settings.useful_min = useful_min[1]
            save_settings()
        end
        imgui.SetNextItemWidth(220 * scale)
        if imgui.SliderInt('Easy Max', useful_max, state.settings.useful_min, state.settings.risky_min - 1, '+%d') then
            state.settings.useful_max = useful_max[1]
            save_settings()
        end
        imgui.SetNextItemWidth(220 * scale)
        if imgui.SliderInt('Difficult Min', risky_min, state.settings.useful_max + 1, state.settings.risky_max, '+%d') then
            state.settings.risky_min = risky_min[1]
            save_settings()
        end

        local difficult_max = { state.settings.risky_max }
        imgui.SetNextItemWidth(220 * scale)
        if imgui.SliderInt(
            'Difficult Max',
            difficult_max,
            state.settings.risky_min,
            MAX_RECIPE_SKILL_GAP,
            '+%d'
        ) then
            state.settings.risky_max = difficult_max[1]
            save_settings()
        end

        local hq1 = { state.settings.hq1 }
        imgui.SetNextItemWidth(220 * scale)
        if imgui.SliderInt('HQ Min', hq1, 1, 100, '+%d') then
            state.settings.hq1 = hq1[1]
            save_settings()
        end

        imgui.Spacing()
        if imgui.Button('Reset UI defaults', { 150 * scale, 0 }) then
            state.pending_ui_scale = nil
            state.settings.scale = default_settings.scale
            state.settings.launcher_scale = default_settings.launcher_scale
            state.settings.artisan_button_rounded = false
            state.settings.show_artisan_button = default_settings.show_artisan_button
            state.settings.show_recipe_craft_count = default_settings.show_recipe_craft_count
            state.settings.locked = default_settings.locked
            state.settings.position_x = default_settings.position_x
            state.settings.position_y = default_settings.position_y
            state.settings.show_empty_crafts = default_settings.show_empty_crafts
            state.settings.remember_opened_categories = default_settings.remember_opened_categories
            state.settings.opened_categories = T{}
            state.settings.remember_jump_location = default_settings.remember_jump_location
            clear_recipe_jump(true)
            reset_theme_settings()
            for _, source in ipairs(MATERIAL_SOURCES) do
                state.settings[source.setting] = default_settings[source.setting]
            end
            state.visible[1] = default_settings.visible
            state.position_applied = false
            inventory.invalidate()
            save_settings()
        end
        imgui.SameLine(0, 7 * scale)
        if imgui.Button('Reset difficulties', { 150 * scale, 0 }) then
            state.settings.useful_min = default_settings.useful_min
            state.settings.useful_max = default_settings.useful_max
            state.settings.risky_min = default_settings.risky_min
            state.settings.risky_max = default_settings.risky_max
            state.settings.hq1 = default_settings.hq1
            save_settings()
        end
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()
end

local function render_colors_window()
    if not state.colors_open[1] then
        state.color_picker_open[1] = false
        state.color_picker_target = nil
        return
    end

    local scale = get_ui_scale()
    if not state.colors_position_applied then
        imgui.SetNextWindowPos(
            {
                (tonumber(state.settings.position_x) or 80) + (420 * scale),
                (tonumber(state.settings.position_y) or 180) + (60 * scale),
            },
            ImGuiCond_Always
        )
        state.colors_position_applied = true
    end
    imgui.SetNextWindowSizeConstraints(
        { 360 * scale, 0 },
        { 520 * scale, 620 * scale }
    )

    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 14 * scale, 12 * scale })

    local flags = bit.bor(
        WINDOW_FLAGS,
        ImGuiWindowFlags_AlwaysAutoResize or 0,
        ImGuiWindowFlags_NoSavedSettings or 0
    )
    local began = imgui.Begin('Window Color Theme', state.colors_open, flags)
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))

        if imgui.Button('Restore Default Theme', { 190 * scale, 0 }) then
            reset_theme_settings()
            save_settings()
        end

        imgui.Spacing()
        local color_targets = {
            { key = 'window', label = 'Window' },
            { key = 'font', label = 'Font' },
            { key = 'accent', label = 'Accent' },
        }
        render_section_bar('COLORS')
        local color_flags = bit.bor(
            ImGuiColorEditFlags_NoAlpha or 0,
            ImGuiColorEditFlags_NoInputs or 0,
            ImGuiColorEditFlags_NoPicker or 0
        )
        for _, target in ipairs(color_targets) do
            local red_key = target.key .. '_color_r'
            local green_key = target.key .. '_color_g'
            local blue_key = target.key .. '_color_b'
            local selected_color = {
                state.settings[red_key],
                state.settings[green_key],
                state.settings[blue_key],
            }
            local row_start = imgui.GetCursorPosX()
            imgui.Text(target.label)
            imgui.SameLine()
            imgui.SetCursorPosX(row_start + (90 * scale))
            imgui.ColorEdit3(
                '##ThemeColor' .. target.label,
                selected_color,
                color_flags
            )
            local left_button = ImGuiMouseButton_Left or 0
            if imgui.IsItemClicked(left_button) then
                local io = imgui.GetIO()
                state.color_picker_target = target.key
                state.color_picker_open[1] = true
                state.color_picker_pending = true
                state.color_picker_x = tonumber(io.MousePos.x) or 0
                state.color_picker_y = tonumber(io.MousePos.y) or 0
            end
        end

        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()
end

local function render_color_picker_window()
    if not state.color_picker_open[1] or state.color_picker_target == nil then
        return
    end

    local scale = get_ui_scale()
    local target = state.color_picker_target
    local labels = {
        window = 'Window Color',
        font = 'Font Color',
        accent = 'Accent Color',
    }
    local title = (labels[target] or 'Color') .. '###ArtisanColorPicker'
    if state.color_picker_pending then
        imgui.SetNextWindowPos(
            {
                state.color_picker_x + (8 * scale),
                state.color_picker_y + (8 * scale),
            },
            ImGuiCond_Always
        )
        imgui.SetNextWindowFocus()
    end
    imgui.SetNextWindowSizeConstraints(
        { 330 * scale, 0 },
        { 520 * scale, 620 * scale }
    )

    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 12 * scale, 10 * scale })
    local flags = bit.bor(
        WINDOW_FLAGS,
        ImGuiWindowFlags_AlwaysAutoResize or 0,
        ImGuiWindowFlags_NoSavedSettings or 0
    )
    local began = imgui.Begin(title, state.color_picker_open, flags)
    local hovered = false
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))
        local red_key = target .. '_color_r'
        local green_key = target .. '_color_g'
        local blue_key = target .. '_color_b'
        local selected_color = {
            state.settings[red_key],
            state.settings[green_key],
            state.settings[blue_key],
        }
        imgui.SetNextItemWidth(300 * scale)
        if imgui.ColorPicker3(
            '##ArtisanColorPickerValue',
            selected_color,
            ImGuiColorEditFlags_NoAlpha or 0
        ) then
            state.settings[red_key] = selected_color[1]
            state.settings[green_key] = selected_color[2]
            state.settings[blue_key] = selected_color[3]
            save_settings()
        end
        hovered = imgui.IsWindowHovered()
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()

    local was_pending = state.color_picker_pending
    state.color_picker_pending = false
    local left_button = ImGuiMouseButton_Left or 0
    if not state.color_picker_open[1]
        or (not was_pending and not hovered and imgui.IsMouseClicked(left_button, false)) then
        state.color_picker_open[1] = false
        state.color_picker_target = nil
    end
end

local function render_help_entry(label, description)
    imgui.TextColored(COLORS.heading, label)
    imgui.TextWrapped(description)
    imgui.Spacing()
end

local function render_help_window()
    if not state.help_open[1] then
        return
    end

    local scale = get_ui_scale()
    local context = state.help_context
    if context ~= 'craftbook' and context ~= 'settings' then
        context = 'artisan'
    end
    local help_titles = {
        artisan = 'Artisan Help###ArtisanHelp',
        craftbook = 'Craftbook Help###ArtisanHelp',
        settings = 'Settings Help###ArtisanHelp',
    }
    local title = help_titles[context]
    local artisan_x = tonumber(state.artisan_window_x)
        or tonumber(state.settings.position_x)
        or 80
    local artisan_y = tonumber(state.artisan_window_y)
        or tonumber(state.settings.position_y)
        or 180
    local artisan_width = tonumber(state.artisan_window_width) or (385 * scale)
    imgui.SetNextWindowPos(
        {
            artisan_x + (artisan_width / 2),
            artisan_y - (8 * scale),
        },
        ImGuiCond_Appearing,
        { 0.5, 1.0 }
    )
    imgui.SetNextWindowSizeConstraints(
        { 390 * scale, 0 },
        { 520 * scale, 700 * scale }
    )

    push_artisan_theme(scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7 * scale)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 14 * scale, 12 * scale })
    local flags = bit.bor(WINDOW_FLAGS, ImGuiWindowFlags_AlwaysAutoResize or 0)
    local began = imgui.Begin(title, state.help_open, flags)
    if began then
        imgui.PushFont(nil, math.floor(13 * scale))
        if context == 'settings' then
            render_help_entry(
                'Show empty craft sections',
                'Keeps a craft section visible even when you do not currently have the materials for any recipe in it.'
            )
            render_help_entry(
                'Close windows separately',
                'Lets Craftbook, Filters, Settings, and other Artisan windows remain open when the main Artisan window is closed.'
            )
            render_help_entry(
                'Remember opened categories',
                'Restores the craft and rank sections you left open. When disabled, categories return to their normal collapsed state as you switch crafts or reopen windows.'
            )
            render_help_entry(
                'Remember Jump to Recipe Location',
                'Keeps the jumped-to recipe outlined until you jump somewhere else. When disabled, the outline clears after you leave or scroll away.'
            )
            render_help_entry(
                'Recipe difficulty',
                'Sets how far a recipe may be above your skill before Artisan calls it Easy or Difficult, and how far above a recipe you must be before it is marked HQ. These settings change the color labels, not whether the recipe can be crafted.'
            )
        elseif context == 'craftbook' then
            render_help_entry(
                'Recipe search',
                'Matches any part of a recipe name across every craft. Select a result to jump to it.'
            )
            render_help_entry(
                'Bookmarks',
                'Check Bookmark on any recipe to add it to Bookmarked Recipes. Uncheck it to remove it.'
            )
            render_help_entry(
                'Jump to Recipe',
                'Right-click a material and choose a recipe. Craftbook switches crafts, opens the right rank, centers the recipe, and outlines it.'
            )
        else
            render_help_entry(
                'Open Filters',
                'Chooses which bags Artisan searches for materials.'
            )
            render_help_entry(
                'Craftable',
                'The number of recipes you can make now with your enabled bags, key items, and current skill.'
            )
            render_help_entry(
                'Craft sections',
                'The last number is that craft\'s available recipe count. Click the row to show or hide its recipes.'
            )
            render_help_entry(
                'Jump to Recipe',
                'Right-click a recipe output, material name, or Own count to open its recipe in Craftbook.'
            )
            render_help_entry(
                'Settings',
                'Type /artisan while the Artisan window is open.'
            )
        end
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleVar(2)
    pop_artisan_theme()
end

local function render_windows()
    local player = get_player()
    if not player or player:GetLoginStatus() ~= 2 then
        return
    end
    if state.pending_recipe_jump ~= nil then
        local pending = state.pending_recipe_jump
        state.pending_recipe_jump = nil
        jump_to_recipe(pending.craft_name, pending.recipe)
    end
    render_recipe_window()
    if state.settings.show_artisan_button ~= false then
        render_launcher_window()
    end
    if not state.visible[1] then
        minimize_artisan_windows()
        if state.settings.close_all_windows_with_artisan ~= false then
            return
        end
    end
    render_craftbook_window()
    render_filters_window()
    render_settings_window()
    render_colors_window()
    render_color_picker_window()
    render_tracker_material_context_menu()
    render_help_window()
end

settings.register('settings', 'settings_update', function (updated)
    if updated then state.settings = updated end
    state.visible[1] = state.settings.visible == true
    state.pending_ui_scale = nil
    state.position_applied = false
    state.filters_position_applied = false
    state.colors_position_applied = false
    state.launcher_position_applied = false
end)

ashita.events.register('d3d_present', 'present_cb', render_windows)

ashita.events.register('command', 'command_cb', function (event)
    local args = event.command:args()
    if #args == 0 or args[1]:lower() ~= '/artisan' then return end
    event.blocked = true
    local command = (#args >= 2 and args[2]:lower()) or nil
    if command == nil then
        if state.visible[1] then
            state.settings_open[1] = true
        else
            state.visible[1] = true
        end
    elseif command == 'settings' then
        state.settings_open[1] = true
    elseif command == 'book' or command == 'craftbook' then
        state.craftbook_open[1] = true
    elseif command == 'toggle' then
        state.visible[1] = not state.visible[1]
    elseif command == 'show' then
        state.visible[1] = true
    elseif command == 'hide' then
        state.visible[1] = false
    elseif command == 'lock' then
        state.settings.locked = true
        say('Window locked.')
    elseif command == 'unlock' then
        state.settings.locked = false
        say('Window unlocked.')
    elseif command == 'refresh' then
        inventory.invalidate()
        say('Inventory cache refreshed.')
    elseif command == 'scale' and #args >= 3 then
        state.settings.scale = math.max(0.75, math.min(3.0, tonumber(args[3]) or 1.0))
        say(('Scale set to %.2f.'):format(state.settings.scale))
    elseif command == 'ranges' and #args >= 5 then
        local useful_min = tonumber(args[3])
        local useful_max = tonumber(args[4])
        local risky_min = tonumber(args[5])
        if not useful_min or not useful_max or not risky_min or
            useful_min > useful_max or useful_max >= risky_min or
            risky_min > MAX_RECIPE_SKILL_GAP then
            say('Usage: /artisan ranges <useful-min> <useful-max> <risky-min>.')
            return
        end
        state.settings.useful_min = useful_min
        state.settings.useful_max = useful_max
        state.settings.risky_min = risky_min
        state.settings.risky_max = math.max(
            risky_min,
            tonumber(state.settings.risky_max) or MAX_RECIPE_SKILL_GAP
        )
        say(('Difficulty ranges set to Easy +%d..+%d and Difficult +%d..+%d.'):
            format(
                useful_min,
                useful_max,
                risky_min,
                state.settings.risky_max
            ))
    elseif (command == 'yellow' or command == 'hq') and #args >= 3 then
        local yellow_gap = tonumber(args[3])
        if not yellow_gap or yellow_gap < 1 or yellow_gap > 100 then
            say('Usage: /artisan yellow <skill-gap>.')
            return
        end
        state.settings.hq1 = yellow_gap
        say(('HQ range starts at +%d skill above the recipe cap.'):format(yellow_gap))
    else
        say('Commands: settings, book, toggle, show, hide, lock, unlock, refresh, scale, ranges, yellow.')
    end
    save_settings()
end)

ashita.events.register('unload', 'unload_cb', function ()
    state.settings.visible = state.visible[1]
    settings.save()
    resources.clear()
end)
