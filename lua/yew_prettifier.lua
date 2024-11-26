local M = {}

local default_config = {
    -- Default tab size for prettification
    tab_size = 4,

    -- When to wrap inlined HTML block
    --   Default to file word wrap
    --   Set this setting to 0 to never inline HTML blocks
    max_line_width = nil,

    custom_keymaps = {
        -- Custom keybinding for visual mode prettification
        visual_mode = "go",

        -- Custom keybinding for lookahead
        normal_mode = "go",
    },

    -- Selectively enable normal mode keymap
    enable_prettify_selection = true,

    -- Selectively enable visual mode keymap
    enable_prettify_lookahead = true,
}


-- Load dependencies
local parser = require('parser')
local generatePrettifiedHTML = require('html_prettifier')

-- Load and inject dependencies into vim functions
local prettify_selection, prettify_lookahead = require('vim_funcs')({
    parser = parser,
    generatePrettifiedHTML = generatePrettifiedHTML
})

-- Map 'qp' in visual mode to call the prettify_selection function
vim.api.nvim_set_keymap('v', 'qo', '', { noremap = true, silent = false, callback = prettify_selection })
vim.api.nvim_set_keymap('n', 'qo', '', { noremap = true, silent = false, callback = prettify_lookahead })

-- Load dependencies
local parser = require("parser")
local html_prettifier = require("html_prettifier")
local vim_funcs = require("vim_funcs")

local config = {}

-- Plugin setup function
function M.setup(user_config)
    -- Current configuration (can be updated during setup)
    config = vim.tbl_extend("force", default_config, user_config or {})

    -- Inject dependencies into vim functions
    local prettify_selection, prettify_lookahead = vim_funcs({
        parser = parser,
        generatePrettifiedHTML = html_prettifier,
        config = config
    })

    -- Export internal functions for external use
    M.prettify_selection = prettify_selection
    M.prettify_lookahead = prettify_lookahead
    M.yew_prettify_html = function(input)
        local ast_result = parser(input)
        generatePrettifiedHTML(ast_result, 0, config.tab_size)
    end

    if config.enable_prettify_selection then
        vim.api.nvim_set_keymap("v", config.custom_keymaps.visual_mode, "", {
            noremap = true,
            silent = false,
            callback = prettify_selection,
        })

        vim.api.nvim_create_user_command("YewPrettifySelection", prettify_selection,
            { desc = "Prettify selected yew HTML block" })
    end


    if config.enable_prettify_lookahead then
        vim.api.nvim_set_keymap("n", config.custom_keymaps.normal_mode, "", {
            noremap = true,
            silent = false,
            callback = prettify_lookahead,
        })

        vim.api.nvim_create_user_command("YewPrettifyNext", prettify_lookahead,
            { desc = "Prettify the next yew HTML block in file" })
    end

    local rtp = vim.api.nvim_get_runtime_file("doc/vim-yew-prettifier.txt", false)
    if #rtp > 0 then
        vim.cmd("helptags " .. vim.fn.fnameescape(vim.fn.fnamemodify(rtp[1], ":h")))
    else
        vim.notify("[Yew Prettifier] Help file not found in runtimepath", vim.log.levels.WARN)
    end
end

return M
