local M = {}
local groups = {
    foreground = { "Identifier", "@variable", "@variable.parameter", "@module" },
    comment = { "Comment", "SpecialComment", "@comment" },
    keyword = { "Statement", "Conditional", "Repeat", "Label", "Keyword", "Exception", "StorageClass", "@keyword", "@label", "@tag" },
    func = { "Function", "PreProc", "Include", "Define", "Macro", "PreCondit", "@function" },
    string = { "String", "Character", "@string", "@character" },
    number = { "Number", "Float", "Boolean", "@number", "@boolean" },
    constant = { "Constant", "Special", "SpecialChar", "Tag", "Debug", "@constant", "@variable.builtin", "@string.escape" },
    type = { "Type", "Structure", "Typedef", "@type", "@constructor" },
    property = { "@property", "@variable.member", "@attribute", "@tag.attribute" },
    punctuation = { "Operator", "Delimiter", "@operator", "@keyword.operator", "@punctuation", "@tag.delimiter" },
}
local semantic = {
    namespace = "foreground", variable = "foreground", parameter = "foreground",
    type = "type", class = "type", enum = "type", interface = "type", struct = "type", typeParameter = "type",
    property = "property", decorator = "property", enumMember = "constant", event = "func",
    ["function"] = "func", method = "func", macro = "func", keyword = "keyword", modifier = "keyword",
    comment = "comment", string = "string", regexp = "string", number = "number", operator = "punctuation",
}
local captures = {}
for role, names in pairs(groups) do for _, name in ipairs(names) do captures[name] = role end end

local function role_for(name)
    local special = name:match("^@comment%.([^.]+)")
    if special == "error" or special == "warning" or special == "todo" or special == "note" then return nil end
    local token = name:match("^@lsp%.type%.([^.]+)") or name:match("^@lsp%.typemod%.([^.]+)")
    if token then return semantic[token] end
    while name do
        if captures[name] then return captures[name] end
        name = name:match("^(.*)%.[^.]+$")
    end
end

function M.apply(palette, options, known)
    local c, u = palette.colors, palette.ui
    local set = function(name, attributes) vim.api.nvim_set_hl(0, name, attributes) end
    local bg = options.transparent and "NONE" or u.surface
    local float = options.transparent and "NONE" or u.surface_container
    local ui = {
        Normal = { fg = c.foreground, bg = bg },
        NormalNC = { fg = c.foreground, bg = bg },
        NormalFloat = { fg = c.foreground, bg = float },
        FloatBorder = { fg = u.primary, bg = float },
        FloatTitle = { fg = u.primary, bg = float, bold = true },
        FloatFooter = { fg = u.outline, bg = float },
        Cursor = { fg = u.on_primary, bg = u.primary },
        TermCursor = { reverse = true },
        TermCursorNC = { fg = u.surface, bg = u.outline },
        CursorLine = { bg = u.cursorline },
        CursorColumn = { bg = u.cursorline },
        CursorLineNr = { fg = u.primary, bold = true },
        CursorLineSign = { fg = u.primary, bg = u.cursorline },
        LineNr = { fg = u.outline },
        SignColumn = { fg = u.outline, bg = bg },
        FoldColumn = { fg = u.outline, bg = bg },
        Folded = { fg = u.outline, bg = u.surface_high },
        Visual = { fg = u.on_selection, bg = u.selection },
        Search = { fg = u.on_primary, bg = u.primary },
        CurSearch = { fg = u.on_primary, bg = u.primary, bold = true },
        MatchParen = { fg = u.primary, bold = true, underline = true },
        StatusLine = { fg = c.foreground, bg = u.surface_container },
        StatusLineNC = { fg = u.outline, bg = u.surface_low },
        WinBar = { fg = c.foreground, bg = bg },
        WinBarNC = { fg = u.outline, bg = bg },
        WinSeparator = { fg = u.border, bg = bg },
        TabLine = { fg = u.outline, bg = u.surface_low },
        TabLineSel = { fg = u.primary, bg = u.surface_high, bold = true },
        TabLineFill = { bg = u.surface_low },
        Pmenu = { fg = c.foreground, bg = u.surface_container },
        PmenuSel = { fg = u.on_selection, bg = u.selection },
        PmenuSbar = { bg = u.surface_high },
        PmenuThumb = { bg = u.primary },
        PmenuMatch = { fg = u.primary, bold = true },
        PmenuMatchSel = { fg = u.on_selection, bold = true },
        PmenuBorder = { fg = u.primary, bg = u.surface_container },
        PmenuKind = { fg = c.type, bg = u.surface_container },
        PmenuExtra = { fg = c.comment, bg = u.surface_container },
        NonText = { fg = u.border },
        Whitespace = { fg = u.border },
        EndOfBuffer = { fg = u.border },
        Directory = { fg = u.primary },
        Title = { fg = u.primary, bold = true },
        Question = { fg = u.primary },
        MoreMsg = { fg = u.primary },
        ModeMsg = { fg = c.foreground, bold = true },
        MsgArea = { fg = c.foreground },
        MsgSeparator = { fg = u.border, bg = u.surface_low },
        ErrorMsg = { fg = u.error },
        WarningMsg = { fg = u.warning },
        SpellBad = { undercurl = true, sp = u.error },
        SpellCap = { undercurl = true, sp = u.info },
        SpellRare = { undercurl = true, sp = u.hint },
        SpellLocal = { undercurl = true, sp = u.primary },
        QuickFixLine = { fg = u.on_selection, bg = u.selection },
        DiffAdd = { bg = u.diff_add },
        DiffChange = { bg = u.diff_change },
        DiffDelete = { fg = u.deleted, bg = u.diff_delete },
        DiffText = { bg = u.diff_text, bold = true },
        Added = { fg = u.added },
        Changed = { fg = u.changed },
        Removed = { fg = u.deleted },
        Conceal = { fg = u.outline },
        ColorColumn = { bg = u.surface_high },
        Underlined = { fg = c.func, underline = true },
        Ignore = { fg = u.outline },
        Error = { fg = u.error },
        Todo = { fg = u.primary, bold = true },
        LspReferenceText = { bg = u.cursorline },
        LspInlayHint = { fg = c.comment, bg = u.surface_low },
        LspCodeLens = { fg = c.comment },
        LspSignatureActiveParameter = { fg = u.primary, bold = true },
        ["@markup.strong"] = { bold = true },
        ["@markup.italic"] = { italic = true },
        ["@markup.strikethrough"] = { strikethrough = true },
        ["@markup.underline"] = { underline = true },
        ["@markup.heading"] = { fg = u.primary, bold = true },
        ["@markup.link"] = { fg = c.property },
        ["@markup.link.url"] = { fg = c.property, underline = true },
        ["@markup.raw"] = { fg = c.string },
        ["@markup.list"] = { fg = c.keyword },
        ["@markup.quote"] = { fg = c.comment },
        ["@diff.plus"] = { fg = u.added },
        ["@diff.minus"] = { fg = u.deleted },
        ["@diff.delta"] = { fg = u.changed },
        ["@lsp.mod.deprecated"] = { strikethrough = true },
        BlinkCmpLabelDeprecated = { strikethrough = true },
    }
    for severity, color in pairs({ Error = u.error, Warn = u.warning, Info = u.info, Hint = u.hint, Ok = u.added }) do
        ui["Diagnostic" .. severity] = { fg = color }
        ui["DiagnosticUnderline" .. severity] = { undercurl = true, sp = color }
        for _, kind in ipairs({ "Sign", "VirtualText", "VirtualLines", "Floating" }) do
            ui["Diagnostic" .. kind .. severity] = { fg = color }
        end
    end
    for name, attributes in pairs(ui) do set(name, attributes) end

    local names = vim.tbl_extend("force", known, captures)
    for token, role in pairs(semantic) do names["@lsp.type." .. token] = role end
    for name in pairs(names) do
        local role = role_for(name)
        if role then set(name, { fg = c[role], italic = role == "comment" or nil }) end
    end

    -- Links also give plugins loaded later the same theme.
    local links = {
        Normal = { "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeFileName", "TelescopeNormal", "TelescopePromptNormal",
            "TelescopeResultsNormal", "TelescopePreviewNormal" },
        SignColumn = { "NeoTreeSignColumn" },
        NormalFloat = { "NeoTreeFloatNormal", "BlinkCmpDoc", "BlinkCmpSignatureHelp" },
        FloatBorder = { "NeoTreeFloatBorder", "BlinkCmpDocBorder", "BlinkCmpSignatureHelpBorder" },
        FloatTitle = { "NeoTreeFloatTitle" },
        WinSeparator = { "NeoTreeWinSeparator", "NeoTreeVertSplit", "TelescopeBorder", "TelescopePromptBorder",
            "TelescopeResultsBorder", "TelescopePreviewBorder" },
        StatusLine = { "NeoTreeStatusLine" },
        StatusLineNC = { "NeoTreeStatusLineNC" },
        TabLine = { "NeoTreeTabInactive" },
        TabLineSel = { "NeoTreeTabActive" },
        Directory = { "NeoTreeDirectoryName", "NeoTreeDirectoryIcon", "NeoTreeRootName", "NeoTreeSymbolicLinkTarget" },
        CursorLine = { "NeoTreeCursorLine", "TelescopeSelection" },
        Title = { "NeoTreeTitleBar", "TelescopeTitle", "TelescopePromptTitle", "TelescopeResultsTitle", "TelescopePreviewTitle" },
        Comment = { "NeoTreeGitIgnored", "NeoTreeIgnored", "NeoTreeDimText", "NeoTreeFadeText1", "NeoTreeFadeText2",
            "NeoTreeMessage", "BlinkCmpLabelDescription", "BlinkCmpLabelDetail", "BlinkCmpGhostText" },
        Added = { "GitSignsAdd", "NeoTreeGitAdded", "NeoTreeGitUntracked", "NeoTreeGitUnstaged", "NeoTreeGitStaged" },
        Changed = { "GitSignsChange", "NeoTreeGitModified", "NeoTreeGitRenamed", "NeoTreeModified" },
        Removed = { "GitSignsDelete", "NeoTreeGitDeleted", "NeoTreeGitConflict" },
        Pmenu = { "BlinkCmpMenu" },
        PmenuBorder = { "BlinkCmpMenuBorder" },
        PmenuSel = { "BlinkCmpMenuSelection" },
        PmenuMatch = { "BlinkCmpLabelMatch", "TelescopeMatching" },
        Function = { "BlinkCmpKindFunction", "BlinkCmpKindMethod", "TelescopeResultsMethod" },
        Type = { "BlinkCmpKindClass", "BlinkCmpKindInterface", "BlinkCmpKindStruct", "TelescopeResultsStruct" },
        Identifier = { "BlinkCmpLabel" },
        Special = { "BlinkCmpKind" },
        DiagnosticError = { "@comment.error" },
        DiagnosticWarn = { "@comment.warning" },
        Todo = { "@comment.todo" },
        Visual = { "VisualNOS" },
        CurSearch = { "IncSearch", "Substitute" },
        Cursor = { "lCursor" },
        NonText = { "SpecialKey", "NeoTreeIndentMarker", "NeoTreeExpander", "NeoTreeDotfile", "NeoTreeHiddenByName",
            "NeoTreeWindowsHidden", "NeoTreeEndOfBuffer", "NeoTreeTabSeparatorActive", "NeoTreeTabSeparatorInactive" },
        LspReferenceText = { "LspReferenceRead", "LspReferenceWrite", "LspReferenceTarget" },
        LspCodeLens = { "LspCodeLensSeparator" },
        DiagnosticInfo = { "@comment.note", "DebugPC" },
        QuickFixLine = { "DebugBreakpoint" },
    }
    for target, aliases in pairs(links) do
        for _, alias in ipairs(aliases) do set(alias, { link = target }) end
    end
    for index, color in ipairs({ u.surface_low, u.error, c.string, c.type, c.func, c.keyword, c.property, c.foreground }) do
        vim.g["terminal_color_" .. (index - 1)] = color
        vim.g["terminal_color_" .. (index + 7)] = index == 1 and u.outline or color
    end
end

return M
