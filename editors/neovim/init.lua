-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- `mapleader` and `maplocalleader` must be loaded before lazy.nvim
-- (and should be loaded before the rest of the config because it is just simpler that way)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- editor
vim.opt.tabstop = 4 -- A TAB character looks like 4 spaces
vim.opt.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.opt.softtabstop = 4 -- Number of spaces inserted instead of a TAB character
vim.opt.shiftwidth = 4 -- Number of spaces inserted when indenting

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
-- turn off search higlight with <leader><space>
vim.keymap.set('n', '<leader> ', vim.cmd.nohlsearch, {})
-- flash yanked sections on yank
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})
-- show search result in the middle of the screen
vim.keymap.set('n', 'n', 'nzz', {})
vim.keymap.set('n', 'N', 'Nzz', {})
vim.keymap.set('n', '*', '*zz', {})
vim.keymap.set('n', '#', '#zz', {})
vim.keymap.set('n', 'g*', 'g*zz', {})
vim.keymap.set('n', 'g#', 'g#zz', {})
-- highlight last inserted text
vim.keymap.set('n', 'gV', '`[v`]', {})
-- land big scrolls in the middle of the screen
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', '<C-b>', '<C-b>zz')
vim.keymap.set('n', '<C-f>', '<C-f>zz')

-- style
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.showcmd = true
vim.opt.list = true
-- with this, copying bits of code (with the mouse) includes dots as spaces,
-- use "*y to cleanly (properly) copying to the clipboard
vim.opt.listchars = 'trail:+,tab:>-,nbsp:␣,space:.'


-- other remapping
-- when my pinky is tired
vim.keymap.set('i', 'jkjk', '<Esc>')
vim.keymap.set('i', 'jjj', '<Esc>')
vim.keymap.set('i', 'kkk', '<Esc>')
-- buffers
vim.keymap.set('n', '<leader>bl', vim.cmd.buffers, {})
vim.keymap.set('n', '<leader>bn', vim.cmd.bnext, {})
vim.keymap.set('n', '<leader>bp', vim.cmd.bprevious, {})
vim.keymap.set('n', '<leader>q', vim.cmd.q, {})

-- other
vim.opt.wildmenu = true

-- window resizing
vim.keymap.set('n', '<leader>,', '20<C-w><')
vim.keymap.set('n', '<leader>.', '20<C-w>>')

-- Allow the mouse to resize windows
-- TODO: find a "cleaner" way to resize wndows with the mouse without mouving the cursor
-- This also allows to activate Visual which is fine I guess
-- vim.opt.mouse = ""
vim.keymap.set("n", "<LeftMouse>", "m'<LeftMouse>")
vim.keymap.set("n", "<LeftRelease>", "<LeftRelease>g``")

require("lazy").setup({
    spec = {
        {
            --  an IDE like search interface
            'nvim-telescope/telescope.nvim', tag = '0.1.8',
            dependencies = {
                { 'nvim-lua/plenary.nvim' },  -- default requirement
                { 'nvim-telescope/telescope-live-grep-args.nvim' }  -- adds ripgrep arguments support to <leader>fg
            },
            config = function()
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
            end,
        },
        {
            --supercharged highlighting
            'nvim-treesitter/nvim-treesitter',
            build = ":TSUpdate",
            opts = {
                ensure_installed = {
                    -- required
                    "c",
                    "lua",
                    "vim",
                    "vimdoc",
                    "query",
                    -- required by noice
                    "regex",
                    "markdown",
                    "markdown_inline",
                    -- mine
                    "python",
                    "javascript",
                    "sql",
                    "po",
                    "xml",
                    "css",
                    "scss",
                    "diff",
                    "git_rebase",
                    "git_config",
                    "bash",
                    "yaml",
                },

                -- Install parsers synchronously (only applied to `ensure_installed`)
                sync_install = false,

                -- Automatically install missing parsers when entering buffer
                -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
                auto_install = true,

                -- List of parsers to ignore installing (or "all")
                -- ignore_install = { "javascript" },

                ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
                -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

                highlight = {
                    enable = true,

                    -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
                    -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
                    -- the name of the parser)
                    -- list of language that will be disabled
                    -- disable = { "c", "rust" },

                    -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
                    disable = function(lang, buf)
                        local max_filesize = 100 * 1024 -- 100 KB
                        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                        if ok and stats and stats.size > max_filesize then
                            return true
                        end
                    end,

                    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
                    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
                    -- Using this option may slow down your editor, and you may see some duplicate highlights.
                    -- Instead of true it can also be a list of languages
                    additional_vim_regex_highlighting = false,
                },
            }
        },
        {
            -- extension for treesitter : keep class and function definition within the window
            "nvim-treesitter/nvim-treesitter-context",
            opts = {
                enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
                max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
                min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
                line_numbers = true,
                multiline_threshold = 20, -- Maximum number of lines to show for a single context
                trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
                mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
                -- Separator between context and content. Should be a single character string, like '-'.
                -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
                separator = nil,
                zindex = 20, -- The Z-index of the context window
                on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
            }
        },
        {
            -- git commands integration
            "tpope/vim-fugitive",
        },
        {
            -- fugitiv extension : enables :Gbrowse
            "tpope/vim-rhubarb",
        },
        {
            -- put git diff indication next to the line numbers
            "lewis6991/gitsigns.nvim",
            opts = {},
        },
        {
            -- highlights in red trailling spaces
            "ntpeters/vim-better-whitespace",
        },
        {
            -- add indentation markers
            "lukas-reineke/indent-blankline.nvim",
        },
        {
            -- a theme
            "rebelot/kanagawa.nvim",
            init = function()
                vim.opt.termguicolors = true
                vim.cmd.colorscheme "kanagawa"
            end,
        },
        {
            -- file explorer
            "nvim-tree/nvim-tree.lua",
            opts = {},
            init = function()
                vim.keymap.set("n", "-", vim.cmd.NvimTreeFindFile, {})
                vim.keymap.set("n", "_", vim.cmd.NvimTreeClose, {})
            end,
        },
        {
            -- extension for nvim tree: displays nice looking file type icons
            "nvim-tree/nvim-web-devicons",
            opts = { default = true},
        },
        {
            -- cool looking command prompt
            "folke/noice.nvim",
            opts = {
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
                messages = {
                    enabled = false,
                },
            },
            dependencies = {
                "MunifTanjim/nui.nvim", -- required
                "rcarriga/nvim-notify", -- optional
            },
            init = function()
                -- make spell check play nice with noice
                vim.keymap.set('n', 'z=', 'ea<C-X>s')  -- z=  opens a dropdown rather than a full window, this breaks the counter feature of z=
            end,
        },
        {
            -- language server manager
            'VonHeikemen/lsp-zero.nvim',
            branch = 'v3.x',
            dependencies = {
                -- automate lsp installation
                { 'williamboman/mason.nvim' },
                { 'williamboman/mason-lspconfig.nvim' },
                -- strict dependencies
                { 'neovim/nvim-lspconfig' },
                { 'hrsh7th/nvim-cmp' },
                { 'hrsh7th/cmp-nvim-lsp' },
                { 'L3MON4D3/LuaSnip' },
            },
            lazy = true,
            config = function()
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

                vim.diagnostic.config({
                    virtual_text = false,
                })

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

            end,
        },
        {
            -- code completion menu
            "hrsh7th/cmp-buffer",
            lazy = true,
            config = function()
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
            end,
        },
        {
            -- add completion for nvim specific lua
            "hrsh7th/cmp-nvim-lua",
        },
        {
            -- odoo LSP
            'whenrow/odoo-ls.nvim',
            enabled = function()
                return false
                -- only loaded if nvim is started in one of my odoo workspaces
                -- return vim.fn.isdirectory('odoo') ~= 0 and vim.fn.isdirectory('enterprise') ~= 0 and vim.fn.isdirectory('design-themes') ~= 0 and vim.fn.isdirectory('src') ~= 0
            end,
            requires = { {'neovim/nvim-lspconfig'} },
            config = function()
                local odools = require('odools')
                local r = vim.fn.getcwd()
                odools.setup({
                    -- mandatory
                    odoo_path = r .. "/odoo/",
                    python_path = r .. "/venv/bin/python3",
                    server_path = r .. "/src/odoo-ls/server/target/release/odoo_ls_server", -- compiled from source

                    -- optional
                    addons = {r .. "/enterprise/", r .. "/design-themes/", r .. "/src/internal/default", r .. "/src/internal/private", r .. "/src/internal/trial"},
                    additional_stubs = { r .. "/src/misc_gists/typeshed/stubs"},
                    root_dir = r, -- working directory, odoo_path if empty
                    settings = {
                        autoRefresh = true,
                        autoRefreshDelay = nil,
                        diagMissingImportLevel = "none",
                    },
                })
            end,
        },


    },
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "habamax" } },
    -- automatically check for plugin updates
    checker = { enabled = true },
})
