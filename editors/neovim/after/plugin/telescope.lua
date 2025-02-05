local tb = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', tb.find_files, {})
vim.keymap.set('n', '<leader>fg', ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
vim.keymap.set('n', '<leader>fb', tb.buffers, {})
vim.keymap.set('n', '<leader>fh', tb.help_tags, {})
vim.keymap.set('n', '<leader>fs', tb.lsp_document_symbols, {})
vim.keymap.set('n', '<leader>fo', tb.oldfiles, {})
vim.keymap.set('n', '<leader>fw', tb.grep_string, {})  -- search for word under cursor
vim.keymap.set('n', '<leader>fp', tb.builtin, {})  -- list the telescope builtin pickers. To not clutter mappings, but still be able to access many less used pickers
vim.keymap.set('n', '<leader>fr', tb.resume, {}) -- resume last picker (even if I never pressed enter)

local telescope = require("telescope")
local ta = require("telescope.actions")

-- follow symbolic links
local telescopeConfig = require("telescope.config")
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
table.insert(vimgrep_arguments, "-L")

telescope.setup({
    defaults = {
        mappings = {
            i = {
                ["<C-j>"] = ta.cycle_history_next,
                ["<C-k>"] = ta.cycle_history_prev,
            }
        },
        vimgrep_arguments = vimgrep_arguments,
    },
    pickers = {
        find_files = {
            -- follow symlink in file search
            find_command = { "rg", "--files", "-L" },
        },
    },
})

telescope.load_extension("live_grep_args")
