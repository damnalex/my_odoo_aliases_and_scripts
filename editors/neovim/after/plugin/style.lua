-- theme
require('monokai').setup {}

-- gutter
vim.opt.updatetime = 100  -- necessary for gitgutter to be responsive (not really specific to git gutter)

-- show trailing whitespace
require("ibl").setup()
