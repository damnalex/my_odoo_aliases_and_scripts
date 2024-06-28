if vim.g.vscode then
    -- VSCode only
else
    -- Neovim only
end
-- common

local tb = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', tb.find_files, {})
vim.keymap.set('n', '<leader>fg', tb.live_grep, {})  --TODO: add extension to be able to focus the search per file type
vim.keymap.set('n', '<leader>fb', tb.buffers, {})
vim.keymap.set('n', '<leader>fh', tb.help_tags, {})
vim.keymap.set('n', '<leader>fs', tb.lsp_document_symbols, {})
vim.keymap.set('n', '<leader>fo', tb.oldfiles, {})
vim.keymap.set('n', '<leader>fw', tb.grep_string, {})

local telescope = require("telescope")
local ta = require("telescope.actions")
telescope.setup({
    defaults = {
        mappings = {
            i = {
                ["<C-j>"] = ta.cycle_history_next,
                ["<C-k>"] = ta.cycle_history_prev,
            }
        }
    }
})
