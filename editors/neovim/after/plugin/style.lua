if vim.g.vscode then
    -- VSCode only
else
    -- Neovim only
end
-- common

vim.opt.termguicolors = true

-- theme
vim.cmd.colorscheme "kanagawa"

-- git info in the gutter
require('gitsigns').setup()

-- show trailing whitespace
require("ibl").setup()

-- command prompt
require("noice").setup({
  lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
    },
  },
  -- you can enable a preset for easier configuration
  presets = {
    -- bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
  },
})

-- make spell check play nice with noice
vim.keymap.set('n', 'z=', 'ea<C-X>s')  -- z=  opens a dropdown rather than a full window, this breaks the counter feature of z=

-- line styling
-- require('lualine').setup()
require("lualine").setup({
  sections = {
    -- make noice play nice with the macro recording notification
    lualine_x = {
      {
        require("noice").api.statusline.mode.get,
        cond = require("noice").api.statusline.mode.has,
        color = { fg = "#ff9e64" },
      }
    },
  },
})
