-- Oklab matrices: https://bottosson.github.io/posts/oklab/ (public domain).
local M = {}

function M.rgb(color)
    assert(type(color) == "string" and color:match("^#%x%x%x%x%x%x$"), "Expected #RRGGBB: " .. tostring(color))
    return { tonumber(color:sub(2, 3), 16) / 255, tonumber(color:sub(4, 5), 16) / 255, tonumber(color:sub(6, 7), 16) / 255 }
end

local function hex(rgb)
    local function byte(x) return math.floor(math.max(0, math.min(1, x)) * 255 + 0.5) end
    return string.format("#%02x%02x%02x", byte(rgb[1]), byte(rgb[2]), byte(rgb[3]))
end

function M.mix(background, foreground, amount)
    local a, b = M.rgb(background), M.rgb(foreground)
    return hex({ a[1] * (1 - amount) + b[1] * amount,
        a[2] * (1 - amount) + b[2] * amount, a[3] * (1 - amount) + b[3] * amount })
end

local function linear(x) return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4 end
local function srgb(x) return x <= 0.0031308 and x * 12.92 or 1.055 * x ^ (1 / 2.4) - 0.055 end

function M.luminance(color)
    local c = M.rgb(color)
    return 0.2126 * linear(c[1]) + 0.7152 * linear(c[2]) + 0.0722 * linear(c[3])
end

function M.contrast(a, b)
    local x, y = M.luminance(a), M.luminance(b)
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end

function M.to_oklch(color)
    local c = M.rgb(color)
    local r, g, b = linear(c[1]), linear(c[2]), linear(c[3])
    local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
    local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
    local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
    local a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    local yellow = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return { 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        math.sqrt(a * a + yellow * yellow), math.deg(math.atan2(yellow, a)) % 360 }
end

local function linear_from_oklch(l, c, h)
    local a, b = c * math.cos(math.rad(h)), c * math.sin(math.rad(h))
    local x = (l + 0.3963377774 * a + 0.2158037573 * b) ^ 3
    local y = (l - 0.1055613458 * a - 0.0638541728 * b) ^ 3
    local z = (l - 0.0894841775 * a - 1.2914855480 * b) ^ 3
    return { 4.0767416621 * x - 3.3077115913 * y + 0.2309699292 * z,
        -1.2684380046 * x + 2.6097574011 * y - 0.3413193965 * z,
        -0.0041960863 * x - 0.7034186147 * y + 1.7076147010 * z }
end

local function in_gamut(rgb)
    for _, x in ipairs(rgb) do if x < -0.0000001 or x > 1.0000001 then return false end end
    return true
end

function M.from_oklch(l, c, h)
    local rgb = linear_from_oklch(l, c, h)
    if not in_gamut(rgb) then
        local low, high = 0, c
        for _ = 1, 18 do
            local middle = (low + high) / 2
            if in_gamut(linear_from_oklch(l, middle, h)) then low = middle else high = middle end
        end
        rgb = linear_from_oklch(l, low, h)
    end
    return hex({ srgb(rgb[1]), srgb(rgb[2]), srgb(rgb[3]) })
end

local function minimum_contrast(color, backgrounds)
    local ratio = math.huge
    for _, background in pairs(backgrounds) do ratio = math.min(ratio, M.contrast(color, background)) end
    return ratio
end

local function readable(color, backgrounds, target)
    if type(backgrounds) == "string" then backgrounds = { backgrounds } end
    if minimum_contrast(color, backgrounds) >= target then return color end
    local white, black = minimum_contrast("#ffffff", backgrounds), minimum_contrast("#000000", backgrounds)
    assert(math.max(white, black) >= target, "Contrast target cannot be met across the theme backgrounds")
    local lch = M.to_oklch(color)
    local low, high = lch[1], white >= black and 1 or 0
    local best = white >= black and "#ffffff" or "#000000"
    for _ = 1, 18 do
        local middle = (low + high) / 2
        local candidate = M.from_oklch(middle, lch[2], lch[3])
        if minimum_contrast(candidate, backgrounds) >= target then high, best = middle, candidate else low = middle end
    end
    return best
end

-- Accept a flat Matugen template or Matugen 4's native --json hex output.
function M.generate(data, options)
    options = options or {}
    assert(type(data) == "table", "Matugen palette must be a JSON object")
    local source = data.colors or data
    assert(type(source) == "table", "Matugen colors must be a JSON object")
    local function get(key, optional)
        local value = source[key]
        if type(value) == "table" then value = (value.default or {}).color end
        if value == nil and optional then return nil end
        assert(value, "Missing Matugen color: " .. key)
        M.rgb(value)
        return value
    end
    local background, foreground = get("surface"), get("on_surface")
    local comment, primary = get("outline"), get("primary")
    local accent = M.to_oklch(primary)
    local target = options.contrast == nil and 4.5 or options.contrast
    assert(type(target) == "number" and target >= 1 and target <= 21, "contrast must be between 1 and 21")
    local dark = M.luminance(background) < M.luminance(foreground)
    local lightness = dark and 0.79 or 0.43
    local chroma, shift = math.max(0.09, math.min(0.16, accent[2] * 1.4)), 10 * math.sin(math.rad(accent[3]))
    local palette = { foreground = foreground, comment = comment, punctuation = comment }
    for role, hue in pairs({ keyword = 300, func = 245, string = 145, type = 95, number = 50, constant = 65, property = 200 }) do
        palette[role] = M.from_oklch(lightness, chroma, hue + shift)
    end
    for role, color in pairs(options.colors or {}) do
        assert(palette[role], "Unknown syntax role: " .. tostring(role))
        M.rgb(color)
        palette[role] = color
    end
    local ui = {
        surface = background,
        surface_low = get("surface_container_low", true) or get("surface_low", true) or M.mix(background, foreground, 0.03),
        surface_container = get("surface_container", true) or M.mix(background, foreground, 0.05),
        surface_high = get("surface_container_high", true) or get("surface_high", true) or M.mix(background, foreground, 0.09),
        border = get("outline_variant", true) or M.mix(background, foreground, 0.25),
        primary = primary,
        selection = get("primary_container", true) or M.mix(background, primary, 0.2),
        cursorline = M.mix(background, primary, 0.1),
        error = get("error", true) or M.from_oklch(lightness, chroma, 25),
    }
    -- Fix background tints before adjusting text, avoiding a feedback loop.
    ui.diff_add = M.mix(background, palette.string, 0.15)
    ui.diff_change = M.mix(background, palette.func, 0.12)
    ui.diff_delete = M.mix(background, ui.error, 0.15)
    ui.diff_text = M.mix(background, palette.func, 0.25)
    local backgrounds = {
        surface = background, cursorline = ui.cursorline, surface_low = ui.surface_low,
        surface_container = ui.surface_container, surface_high = ui.surface_high,
        diff_add = ui.diff_add, diff_change = ui.diff_change, diff_delete = ui.diff_delete, diff_text = ui.diff_text,
    }
    local ratios = {}
    for role, color in pairs(palette) do
        palette[role] = readable(color, backgrounds, target)
        ratios[role] = minimum_contrast(palette[role], backgrounds)
    end
    ui.on_surface, ui.outline = palette.foreground, palette.comment
    ui.primary, ui.error = readable(ui.primary, backgrounds, target), readable(ui.error, backgrounds, target)
    ui.warning, ui.info, ui.hint = palette.number, palette.func, palette.property
    ui.added, ui.changed = palette.string, palette.func
    ui.deleted = ui.error
    ui.on_primary = readable(background, ui.primary, target)
    ui.on_selection = readable(palette.foreground, ui.selection, target)
    return { colors = palette, contrast = ratios, background = background, backgrounds = backgrounds,
        mode = dark and "dark" or "light", ui = ui }
end

return M
