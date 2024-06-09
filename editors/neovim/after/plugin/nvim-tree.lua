-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- empty setup using defaults
require("nvim-tree").setup()
require("nvim-web-devicons").setup{ default = true }

vim.keymap.set("n", "-", vim.cmd.NvimTreeFindFile, {})
vim.keymap.set("n", "_", vim.cmd.NvimTreeClose, {})
