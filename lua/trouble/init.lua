local View = require("trouble.view")
local config = require("trouble.config")
local colors = require("trouble.colors")
local util = require("trouble.util")
local lsp = require("trouble.lsp")

colors.setup()

local Trouble = {}

local view

local function is_open() return view and view:is_valid() end

function Trouble.setup(options)
    config.setup(options)
    colors.setup()
end

function Trouble.close() if is_open() then view:close() end end

function Trouble.open(opts)
    opts = opts or {}
    if opts.mode and (opts.mode ~= config.options.mode) then
        Trouble.action("toggle_mode")
    end

    if is_open() then
        view:focus()
    else
        view = View.create(opts)
    end
end

function Trouble.toggle(opts)
    opts = opts or {}

    if opts.mode and (opts.mode ~= config.options.mode) then
        Trouble.action("toggle_mode")
        Trouble.open()
        return
    end

    if is_open() then
        Trouble.close()
    else
        Trouble.open()
    end
end

function Trouble.help()
    local lines = {"# Key Bindings"}
    local height = 1
    for command, key in pairs(config.options.action_keys) do
        if type(key) == "table" then key = table.concat(key, " | ") end
        table.insert(lines, " * **" .. key .. "** " .. command:gsub("_", " "))
        height = height + 1
    end
    -- help
    vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "single",
        height = 20,
        offset_y = -2,
        offset_x = 2
    })
end

local updater = util.debounce(100, function()
    util.debug("refresh: auto")
    view:update({auto = true})
end)

function Trouble.refresh(opts)
    if is_open() then
        if opts and opts.auto then
            updater()
        else
            util.debug("refresh")
            view:update(opts)
        end
    elseif opts.auto and config.options.auto_open then
        local count = util.count(lsp.diagnostics())
        if count > 0 then Trouble.open(opts) end
    end
end

function Trouble.action(action)
    if action == "toggle_mode" then
        if config.options.mode == "document" then
            config.options.mode = "workspace"
        else
            config.options.mode = "document"
        end
        action = "refresh"
    end

    if view and action == "on_win_enter" then view:on_win_enter() end
    if not is_open() then return end
    if action == "hover" then view:hover() end
    if action == "jump" then view:jump() end
    if action == "jump_close" then
        view:jump()
        Trouble.close()
    end
    if action == "open_folds" then Trouble.refresh({open_folds = true}) end
    if action == "close_folds" then Trouble.refresh({close_folds = true}) end
    if action == "toggle_fold" then view:toggle_fold() end
    if action == "on_enter" then view:on_enter() end
    if action == "on_leave" then view:on_leave() end
    if action == "cancel" then view:switch_to_parent() end
    if action == "next" then view:next_item() end
    if action == "previous" then view:previous_item() end

    if action == "toggle_preview" then
        config.options.auto_preview = not config.options.auto_preview
        if not config.options.auto_preview then
            view:close_preview()
        else
            action = "preview"
        end
    end
    if action == "auto_preview" and config.options.auto_preview then
        action = "preview"
    end
    if action == "preview" then view:preview() end

    if Trouble[action] then Trouble[action]() end
end

return Trouble
