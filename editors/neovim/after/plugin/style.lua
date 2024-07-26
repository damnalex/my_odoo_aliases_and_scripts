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

-- line styling
require('lualine').setup()

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
    bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = false, -- add a border to hover docs and signature help
  },
})

-- make spell check play nice with noice
vim.keymap.set('n', 'z=', 'ea<C-X>s')  -- z=  opens a dropdown rather than a full window, this breaks the counter feature of z=
