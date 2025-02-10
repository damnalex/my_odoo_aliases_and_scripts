-- nvim-tree's doc says: disable netrw at the very start of your init.lua
-- but it looks to be working correctly without it anyway
-- furthermore these changes broke the :GBrowse feature of vim-fugitive
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1

-- empty setup using defaults
require("nvim-tree").setup()
require("nvim-web-devicons").setup{ default = true }

vim.keymap.set("n", "-", vim.cmd.NvimTreeFindFile, {})
vim.keymap.set("n", "_", vim.cmd.NvimTreeClose, {})
