if vim.g.vscode then
    -- VSCode only
else
    -- Neovim only
end
-- common

vim.opt.termguicolors = true

-- theme
vim.cmd.colorscheme "kanagawa"

-- gutter
-- necessary for gitgutter to be responsive (the option is not really specific to git gutter)
vim.opt.updatetime = 100

-- show trailing whitespace
require("ibl").setup()
