local M = {}

function M.check()
    local health = vim.health
    local bridge = require("matugen_nvim_bridge")
    local status = bridge.status()

    health.start("matugen-nvim-bridge")
    if vim.fn.has("nvim-0.10.4") == 1 then
        health.ok("Neovim 0.10.4 or newer")
    else
        health.error("Neovim 0.10.4 or newer is required")
        return
    end

    if not status.palette_path then
        health.error("Not configured. Call require('matugen_nvim_bridge').setup({ palette_path = ... })")
        return
    end

    local ok, palette = pcall(function()
        local data = vim.json.decode(table.concat(vim.fn.readfile(status.palette_path), "\n"))
        return bridge.generate(data, status.options)
    end)
    if ok then
        health.ok("Readable Matugen palette: " .. status.palette_path)
        local minimum = math.huge
        for _, ratio in pairs(palette.contrast) do
            minimum = math.min(minimum, ratio)
        end
        health.ok(string.format("Minimum syntax contrast across theme backgrounds: %.2f:1", minimum))
    else
        health.error("Cannot generate a palette: " .. tostring(palette))
    end

    if status.active then
        health.ok("Colorscheme is selected")
    else
        health.info("Another colorscheme is selected; automatic updates are suspended")
    end
    if status.watching then
        health.ok("Watching the palette directory for changes")
    else
        health.info("No active file watcher. Check the directory exists, or use :MatugenNvimBridgeReload")
    end
end

return M
