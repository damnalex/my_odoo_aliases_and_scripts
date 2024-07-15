if vim.g.vscode then
    -- VSCode only
else
    -- Neovim only
end
-- common

local lsp_zero = require('lsp-zero')
lsp_zero.on_attach(function(client, bufnr)
    -- see :help lsp-zero-keybindings
    lsp_zero.default_keymaps({buffer = bufnr})
    -- K: Displays hover information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.hover().
    -- gd: Jumps to the definition of the symbol under the cursor. See :help vim.lsp.buf.definition().
    -- gD: Jumps to the declaration of the symbol under the cursor. Some servers don't implement this feature. See :help vim.lsp.buf.declaration().
    -- gi: Lists all the implementations for the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.implementation().
    -- go: Jumps to the definition of the type of the symbol under the cursor. See :help vim.lsp.buf.type_definition().
    -- gr: Lists all the references to the symbol under the cursor in the quickfix window. See :help vim.lsp.buf.references().
    -- gs: Displays signature information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.signature_help(). If a mapping already exists for this key this function is not bound.
    -- <F2>: Renames all references to the symbol under the cursor. See :help vim.lsp.buf.rename().
    -- <F3>: Format code in current buffer. See :help vim.lsp.buf.format().
    -- <F4>: Selects a code action available at the current cursor position. See :help vim.lsp.buf.code_action().
    -- gl: Show diagnostics in a floating window. See :help vim.diagnostic.open_float().
    -- [d: Move to the previous diagnostic in the current buffer. See :help vim.diagnostic.goto_prev().
    -- ]d: Move to the next diagnostic. See :help vim.diagnostic.goto_next().
end)

-- language server managment
-- doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/guide/integrate-with-mason-nvim.md
require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {
        "ruff",
        "pyright",
    },
    handlers = {
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end,
    },
})

-- completion
local cmp = require('cmp')
local cmp_format = require('lsp-zero').cmp_format({details = true})
local cmp_action = require('lsp-zero').cmp_action()
cmp.setup({
    sources = {
        {name = 'nvim_lsp'},
        {name = 'nvim_lua'},
        {name = 'buffer'},
    },
    mapping = {
        ['<C-y>'] = cmp.mapping.confirm({select = false}),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<Up>'] = cmp.mapping.select_prev_item({behavior = 'select'}),
        ['<Down>'] = cmp.mapping.select_next_item({behavior = 'select'}),
        ['<C-p>'] = cmp.mapping(function()
            if cmp.visible() then
                cmp.select_prev_item({behavior = 'insert'})
            else
                cmp.complete()
            end
        end),
        ['<C-n>'] = cmp.mapping(function()
            if cmp.visible() then
                cmp.select_next_item({behavior = 'insert'})
            else
                cmp.complete()
            end
        end),
    },
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body)
        end,
    },
    -- show completion source
    formatting = cmp_format,
    -- preselect the first completion result
    preselect = 'item',
    completion = {
        completeopt = 'menu,menuone,noinsert'
    },
    -- make it pretty
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
})
