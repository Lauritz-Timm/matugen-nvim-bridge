local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(arg[0], ":p"))))
vim.opt.rtp:append(root)
local engine = require("matugen_nvim_bridge.colors")
local plugin = require("matugen_nvim_bridge")
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local function get(name, links) return vim.api.nvim_get_hl(0, { name = name, link = links or false }) end
local function native(flat)
    local result = { colors = {} }
    for key, value in pairs(flat) do result.colors[key] = { default = { color = value } } end
    return result
end
local function check_contrast(palette, target)
    for background_name, background in pairs(palette.backgrounds) do
        for role, color in pairs(palette.colors) do
            check(engine.contrast(color, background) >= target, "Contrast: " .. role .. " on " .. background_name)
        end
        for _, role in ipairs({ "primary", "error" }) do
            check(engine.contrast(palette.ui[role], background) >= target, "UI contrast: " .. role .. " on " .. background_name)
        end
    end
    check(engine.contrast(palette.ui.on_selection, palette.ui.selection) >= target, "Selection contrast")
    check(engine.contrast(palette.ui.on_primary, palette.ui.primary) >= target, "Search contrast")
end
local dark = { surface = "#101510", on_surface = "#e1e6dd", primary = "#95d5a7", outline = "#8b9388" }
local light = { surface = "#f6fbf3", on_surface = "#171d16", primary = "#326c48", outline = "#737c70" }

check(math.abs(engine.contrast("#000000", "#ffffff") - 21) < 0.00001, "21:1 reference")
for _, color in ipairs({ "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#808080" }) do
    local converted, original = engine.rgb(engine.from_oklch(unpack(engine.to_oklch(color)))), engine.rgb(color)
    for i = 1, 3 do check(math.abs(converted[i] - original[i]) <= 1 / 255, "Oklab round trip") end
end
for _, flat in ipairs({ dark, light }) do
    check_contrast(plugin.generate(flat, { contrast = 7 }), 7)
    for role, ratio in pairs(plugin.generate(flat, { contrast = 7 }).contrast) do
        check(ratio >= 7, "Requested higher contrast: " .. role)
    end
    for _, accent in ipairs({ "#44aa77", "#4488ee", "#cc8822", "#bb4488", "#888888" }) do
        local input = vim.tbl_extend("force", flat, { primary = accent })
        local result = plugin.generate(input)
        check(vim.deep_equal(result, plugin.generate(native(input))), "Native and flat Matugen colors must match")
        check_contrast(result, 4.5)
        for role, color in pairs(result.colors) do check(engine.contrast(color, result.background) >= 4.5, "Contrast: " .. role) end
        local seen = {}
        for _, role in ipairs({ "keyword", "func", "string", "type", "number" }) do
            check(not seen[result.colors[role]], "Distinct syntax role: " .. role)
            seen[result.colors[role]] = true
        end
    end
end
check(plugin.generate(dark, { colors = { func = "#000001" } }).contrast.func >= 4.5, "Correct unreadable custom colors")
check(not pcall(plugin.generate, dark, { colors = { typo = "#123456" } }), "Reject unknown roles")
check(not pcall(plugin.generate, {}, {}), "Reject missing Matugen fields")
check(not pcall(plugin.generate, dark, { contrast = false }), "Reject invalid contrast")
check(not pcall(plugin.generate, dark, { contrast = 21 }), "Reject an impossible target without lowering contrast")
check(not pcall(plugin.generate, false), "Reject a non-object palette")

-- Optionally exercise files produced by the real Matugen executable.
local actual = arg[1] and vim.fn.globpath(arg[1], "*.flat.json", false, true) or {}
for _, path in ipairs(actual) do
    local flat = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    local raw = vim.json.decode(table.concat(vim.fn.readfile(path:gsub("%.flat%.json$", ".native.json")), "\n"))
    local palette = plugin.generate(flat)
    check(vim.deep_equal(palette, plugin.generate(raw)), "Actual Matugen export/template agreement")
    check_contrast(palette, 4.5)
end

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local path = directory .. "/palette.json"
local function write(value, atomic)
    local target = atomic and directory .. "/replacement.json" or path
    vim.fn.writefile({ vim.json.encode(value) }, target)
    if atomic then assert(vim.uv.fs_rename(target, path)) end
end
local function number(color) return tonumber(color:sub(2), 16) end
vim.cmd.colorscheme("habamax")
local initial_normal = get("Normal")
local initial_notify = vim.notify
vim.notify = function() end
plugin.setup({ palette_path = path })
check(vim.deep_equal(get("Normal"), initial_normal), "Keep current highlights when the startup palette is missing")
check(plugin.status().watching, "Watch for the first palette file when its directory exists")
vim.fn.writefile({ "{incomplete" }, path)
plugin.setup({ palette_path = path })
check(vim.deep_equal(get("Normal"), initial_normal), "Keep current highlights when the startup palette is invalid")
check(not plugin.status().loaded and plugin.status().watching, "Keep watching an invalid startup palette")
vim.notify = initial_notify
write(dark, true)
check(vim.wait(1500, function() return plugin.current ~= nil end, 10), "Recover automatically from invalid startup JSON")
local function check_rendered_contrast()
    local normal = get("Normal")
    local function color(value) return string.format("#%06x", value) end
    for _, name in ipairs({ "Normal", "NormalFloat", "FloatTitle", "FloatFooter", "LineNr", "SignColumn", "FoldColumn", "Folded",
        "StatusLine", "StatusLineNC", "WinBar", "WinBarNC", "TabLine", "TabLineSel", "Pmenu", "PmenuSel", "PmenuKind", "PmenuExtra",
        "Search", "CurSearch", "Visual", "LspInlayHint", "BlinkCmpMenu", "NeoTreeNormal", "TelescopeNormal", "TelescopeSelection" }) do
        local attributes = get(name)
        check(engine.contrast(color(attributes.fg or normal.fg), color(attributes.bg or normal.bg)) >= 4.5, "Rendered UI contrast: " .. name)
    end
    for _, name in ipairs({ "CursorLine", "DiffAdd", "DiffChange", "DiffDelete", "DiffText" }) do
        local attributes = get(name)
        for _, role in ipairs({ "Comment", "Function", "Keyword", "String", "Number", "Type", "Identifier" }) do
            check(engine.contrast(color(attributes.fg or get(role).fg), color(attributes.bg)) >= 4.5, "Rendered syntax contrast: " .. role .. " on " .. name)
        end
    end
    local detail = get("BlinkCmpLabelDescription")
    check(engine.contrast(color(detail.fg), color(get("BlinkCmpMenu").bg)) >= 4.5, "Completion detail contrast")
end
local events, observed = 0, nil
vim.api.nvim_create_autocmd("ColorScheme", { pattern = "matugen-nvim-bridge", callback = function()
    events = events + 1
    observed = get("Normal")
end })
write(dark)
vim.cmd.colorscheme("habamax")
vim.api.nvim_set_hl(0, "Function", { fg = "#ff0000", italic = true, bold = true })
vim.api.nvim_set_hl(0, "@function.call.lua", { link = "Function" })
vim.api.nvim_set_hl(0, "@lsp.typemod.function.defaultLibrary.lua", { fg = "#ff0000" })
plugin.setup({ palette_path = path })
check(vim.g.colors_name == "matugen-nvim-bridge", "Register a native colorscheme")
check(plugin.status().active and plugin.status().loaded and plugin.status().watching, "Report active theme and watcher state")
local snapshot = plugin.status()
snapshot.options.palette_path = "/changed"
check(plugin.status().options.palette_path ~= "/changed", "Status options are an independent snapshot")
check(events == 1, "Emit one ColorScheme event on setup")
check(plugin.current.background == dark.surface, "Read Matugen, not the previous colorscheme")
check(vim.o.background == "dark" and vim.o.termguicolors, "Set theme mode and true color")
check_rendered_contrast()
check(get("Normal").bg == number(dark.surface), "Theme the editor background")
check(get("Normal").fg == number(plugin.current.colors.foreground), "Theme the editor foreground")
check(observed.bg == get("Normal").bg, "ColorScheme listeners see the applied theme")
check(get("Function").fg ~= 0xff0000 and not get("Function").bold, "Define syntax independently of the previous theme")
for _, name in ipairs({ "@function", "@function.call.lua", "@lsp.type.function", "@lsp.typemod.function.defaultLibrary.lua" }) do
    check(get(name).fg == get("Function").fg, "Syntax, Treesitter and LSP agree: " .. name)
end
for _, name in ipairs({ "Visual", "Search", "CursorLine", "Pmenu", "StatusLine", "DiffAdd" }) do
    check(get(name).bg ~= nil, "Theme the UI: " .. name)
end
check(get("DiagnosticError").fg ~= get("DiagnosticWarn").fg, "Distinct diagnostic severities")
check(get("@comment.error").fg == get("DiagnosticError").fg, "Keep error comments distinct")
check(get("NeoTreeDirectoryName").fg == get("Directory").fg, "Theme the file explorer")
check(get("TelescopeSelection").bg == get("CursorLine").bg, "Theme the picker")
check(get("BlinkCmpMenu").bg == get("Pmenu").bg, "Theme the completion menu")
check(vim.g.terminal_color_4 == plugin.current.colors.func, "Theme terminal ANSI colors")
check(engine.contrast(plugin.current.ui.on_selection, plugin.current.ui.selection) >= 4.5, "Readable selection")
check(engine.contrast(plugin.current.ui.on_primary, plugin.current.ui.primary) >= 4.5, "Readable search matches")

local first = vim.deepcopy(plugin.current)
plugin.reload()
check(vim.deep_equal(plugin.current, first), "Repeated reads are deterministic")
check(events == 2, "Manual reload emits ColorScheme")
local before = vim.api.nvim_get_hl(0, {})
local notify = vim.notify
vim.notify = function() end
vim.fn.writefile({ "{incomplete" }, path)
check(plugin.reload() == nil, "Reject incomplete JSON")
check(vim.deep_equal(vim.api.nvim_get_hl(0, {}), before), "Keep the entire last working theme")
write({ surface = "#000000" })
check(plugin.reload() == nil, "Reject incomplete palettes")
check(vim.deep_equal(plugin.current, first), "Keep the last working generated palette")
vim.notify = notify
write(native(light), true)
check(vim.wait(1500, function() return plugin.current.background == light.surface end, 10), "Watch atomic palette replacement")
check(vim.o.background == "light", "Switch automatically to light mode")
check_rendered_contrast()
check(get("Normal").bg == number(light.surface), "Update editor UI after replacement")
check(vim.g.terminal_color_4 == plugin.current.colors.func, "Update terminal colors after replacement")
check(observed.bg == number(light.surface), "Notify plugin integrations after replacement")

-- A palette write queued just before changing themes must not take over later.
write(dark)
vim.cmd.colorscheme("desert")
local other = get("Normal")
vim.wait(250)
check(vim.g.colors_name == "desert" and vim.deep_equal(get("Normal"), other), "Respect an explicitly selected different theme")
vim.cmd.colorscheme("matugen-nvim-bridge")
check(plugin.current.background == dark.surface, ":colorscheme reads the latest file")
check(get("Normal").bg == number(dark.surface), ":colorscheme restores the complete theme")
local before_events = events
write(light)
vim.wait(30)
write(dark, true)
vim.wait(250)
check(events == before_events + 1, "Debounce successive writes into one reload")
check(plugin.current.background == dark.surface, "Use the final palette in a burst")

plugin.setup({ palette_path = path, transparent = true, watch = false })
check(not plugin.status().watching, "Report disabled watching")
for _, name in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn",
    "NeoTreeNormal", "TelescopeNormal", "TelescopeBorder" }) do
    check(get(name).bg == nil, "Optional transparency: " .. name)
end
check(get("Visual").bg ~= nil and get("CursorLine").bg ~= nil, "Keep selection and cursorline with transparency")
write(light, true)
vim.wait(200)
check(plugin.current.background == dark.surface, "watch=false closes the previous watcher")
vim.cmd("MatugenNvimBridgeReload")
check(plugin.current.background == light.surface, "The reload command works without watching")
check(get("Normal").bg == nil, "Reload keeps the transparency option")
check(not pcall(plugin.setup, { palette_path = path, transparent = "yes" }), "Validate transparency")
check(not pcall(plugin.setup, { palette_path = path, typo = true }), "Reject unknown setup options")

plugin.setup({ palette_path = path })
check(get("Normal").bg == number(light.surface), "Restore opaque defaults after transparent setup")
plugin.setup({ palette_path = path })
before_events = events
write(dark, true)
check(vim.wait(1500, function() return plugin.current.background == dark.surface end, 10), "Watch after repeated setup")
vim.wait(150)
check(events == before_events + 1, "Repeated setup leaves only one active watcher")
local actual_health = vim.health
local reports = 0
vim.health = {
    start = function() end,
    ok = function() reports = reports + 1 end,
    info = function() end,
    error = function(message) error(message) end,
}
require("matugen_nvim_bridge.health").check()
vim.health = actual_health
check(reports >= 4, "Health check validates the configured input and watcher")
vim.api.nvim_exec_autocmds("VimLeavePre", {})
vim.fn.delete(directory, "rf")
print(string.format("matugen-nvim-bridge: %d checks passed; %d actual Matugen palettes", count, #actual))
