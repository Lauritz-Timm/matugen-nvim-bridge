---@class MatugenNvimBridgeOptions
---@field palette_path string Path to a flat Matugen template or native hex export.
---@field watch? boolean Watch palette changes. Defaults to true.
---@field transparent? boolean Inherit the terminal background. Defaults to false.
---@field contrast? number Minimum text contrast ratio. Defaults to 4.5.
---@field colors? table<string, string> Starting colors for individual syntax roles.

local M = {}
local colors = require("matugen_nvim_bridge.colors")
local highlights = require("matugen_nvim_bridge.highlights")
local name = "matugen-nvim-bridge"
local config = {}
local watcher, timer
local revision = 0

---Generate a complete palette without changing the editor.
---@param data table
---@param options? MatugenNvimBridgeOptions
---@return table
M.generate = colors.generate

local function read()
    local ok, result = pcall(function()
        assert(config.palette_path, "Call setup({ palette_path = ... }) first")
        local data = vim.json.decode(table.concat(vim.fn.readfile(config.palette_path), "\n"))
        return colors.generate(data, config)
    end)

    if not ok then
        vim.notify(name .. ": " .. tostring(result), vim.log.levels.WARN)
        return nil, result
    end

    return result
end

local function apply(palette)
    local known = vim.api.nvim_get_hl(0, {})

    -- Changing 'background' can reload a colorscheme; clear its name first.
    vim.g.colors_name = nil
    vim.o.termguicolors = true
    vim.o.background = palette.mode
    vim.cmd("highlight clear")
    if vim.g.syntax_on then
        vim.cmd("syntax reset")
    end

    highlights.apply(palette, config, known)
    vim.g.colors_name = name
    M.current = palette
    return palette
end

---Entry point for :colorscheme, which emits its own ColorScheme events.
---@return table? palette
---@return string? error
function M.load()
    local palette, failure = read()
    if not palette then
        -- Keep the current highlights while waiting for a valid palette.
        vim.g.colors_name = name
        return nil, failure
    end
    return apply(palette)
end

---Read the file, activate the theme and notify colorscheme integrations.
---@return table? palette
---@return string? error
function M.reload()
    local palette, failure = read()
    if not palette then
        return nil, failure
    end

    vim.api.nvim_exec_autocmds("ColorSchemePre", { pattern = name, modeline = false })
    apply(palette)
    vim.api.nvim_exec_autocmds("ColorScheme", { pattern = name, modeline = false })
    return palette
end

local function close()
    revision = revision + 1
    for _, handle in pairs({ watcher, timer }) do
        if handle and not handle:is_closing() then
            handle:stop()
            handle:close()
        end
    end
    watcher, timer = nil, nil
end

local function schedule_reload()
    if not timer or timer:is_closing() then
        return
    end

    local scheduled_revision = revision
    timer:stop()
    timer:start(100, 0, vim.schedule_wrap(function()
        if scheduled_revision == revision and timer and not timer:is_closing() and vim.g.colors_name == name then
            M.reload()
        end
    end))
end

---Return the current file and watcher state for diagnostics.
---@return table
function M.status()
    return {
        palette_path = config.palette_path,
        watching = watcher ~= nil and watcher:is_active(),
        active = vim.g.colors_name == name,
        loaded = M.current ~= nil,
        options = vim.deepcopy(config),
    }
end

---Configure and activate the colorscheme.
---@param options MatugenNvimBridgeOptions
function M.setup(options)
    assert(vim.fn.has("nvim-0.10.4") == 1, "Neovim 0.10.4 or newer is required")
    assert(type(options) == "table", "setup expects an options table")
    assert(type(options.palette_path) == "string" and options.palette_path ~= "", "palette_path is required")
    for _, key in ipairs({ "watch", "transparent" }) do
        assert(options[key] == nil or type(options[key]) == "boolean", key .. " must be a boolean")
    end
    assert(options.colors == nil or type(options.colors) == "table", "colors must be a table")
    assert(
        options.contrast == nil or type(options.contrast) == "number" and options.contrast >= 1 and options.contrast <= 21,
        "contrast must be between 1 and 21"
    )
    for key in pairs(options) do
        assert(
            key == "palette_path" or key == "watch" or key == "transparent" or key == "contrast" or key == "colors",
            "Unknown option: " .. tostring(key)
        )
    end

    close()
    config = vim.deepcopy(options)
    config.palette_path = vim.fn.fnamemodify(vim.fn.expand(config.palette_path), ":p")

    if config.watch ~= false then
        timer = assert(vim.uv.new_timer())
        watcher = assert(vim.uv.new_fs_event())
        local basename = vim.fs.basename(config.palette_path)

        -- Watching the directory also handles atomic replacement of the JSON file.
        local ok, failure = watcher:start(vim.fs.dirname(config.palette_path), {}, function(error, filename)
            if not error and (not filename or vim.fs.basename(filename) == basename) then
                schedule_reload()
            end
        end)
        if not ok then
            close()
            vim.notify(name .. ": file watch failed: " .. tostring(failure), vim.log.levels.WARN)
        end
    end

    local group = vim.api.nvim_create_augroup("MatugenNvimBridge", { clear = true })
    vim.api.nvim_create_autocmd("ColorSchemePre", {
        group = group,
        callback = function()
            if timer then
                timer:stop()
            end
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = close })
    vim.api.nvim_create_user_command("MatugenNvimBridgeReload", M.reload, {
        force = true,
        desc = "Reload the Matugen colorscheme",
    })
    vim.cmd.colorscheme(name)
end

return M
