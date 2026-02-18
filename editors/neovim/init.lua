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

-- window resizing and navigation
vim.keymap.set('n', '<leader>,', '20<C-w><')
vim.keymap.set('n', '<leader>.', '20<C-w>>')
vim.keymap.set('n', '<leader>h', '<C-w>h')
vim.keymap.set('n', '<leader>j', '<C-w>j')
vim.keymap.set('n', '<leader>k', '<C-w>k')
vim.keymap.set('n', '<leader>l', '<C-w>l')

-- Allow the mouse to resize windows
-- TODO: find a "cleaner" way to resize wndows with the mouse without moving the cursor
-- This also allows to activate Visual which is fine I guess
-- vim.opt.mouse = ""
vim.keymap.set("n", "<LeftMouse>", "m'<LeftMouse>")
vim.keymap.set("n", "<LeftRelease>", "<LeftRelease>g``")

-- fast switch to file explorer
vim.keymap.set("n", "-", vim.cmd.Explore, {})

require("lazy").setup({
    spec = {
        {
            --  an IDE like search interface
            'nvim-telescope/telescope.nvim', tag = '0.1.8',
            dependencies = {
                { 'nvim-lua/plenary.nvim' },  -- default requirement
                { 'nvim-telescope/telescope-live-grep-args.nvim' },  -- adds ripgrep arguments support to <leader>fg
                { 'nvim-telescope/telescope-fzf-native.nvim' }, --faster fuzzy finder
            },
            event = "VeryLazy",
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
                local tlga = require("telescope-live-grep-args.actions")

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
                                 -- most frequent annoyance when looking for translated terms (but i prefer to do it manually rather that risking over excluding by default)
                                ["<C-p>"] = tlga.quote_prompt({ postfix = ' --iglob "!*.po"' }),
                                ["<C-q>"] = tlga.quote_prompt(),  -- this will be on right-ctrl + q, left-ctrl+q still sends the result to the quick fix list
                                -- move the preview only
                                ["<C-u>"] = ta.preview_scrolling_up, -- full height scroll
                                ["<C-d>"] = ta.preview_scrolling_down,
                                -- TODO: find a way to scroll left and right in the preview (will land in 0.2.0 : https://github.com/nvim-telescope/telescope.nvim/issues/3110#issuecomment-2395242266 )
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
                telescope.load_extension("fzf")
            end,
        },
        {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make',
        },
        {
            --supercharged highlighting
            'nvim-treesitter/nvim-treesitter',
            -- enabled = false,
            branch = "master",
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
            -- enabled = false,
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
            event = "VeryLazy",
        },
        {
            -- fugitiv extension : enables :Gbrowse
            "tpope/vim-rhubarb",
            event = "VeryLazy",
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
            -- easy f t horizontal movement
            "unblevable/quick-scope",
        },
        {
            -- cool looking command prompt
            "folke/noice.nvim",
            event = "VeryLazy",
            -- enabled = function()
            --     return false
            -- end,
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
            -- General lsp config
            'neovim/nvim-lspconfig',
            config = function()
                vim.lsp.config('lua_ls', {})
                vim.lsp.enable("lua_ls")
                if vim.fn.filereadable('odools.toml') == 1 then
                    -- odoo workspace, try to use just odoo-ls
                    -- see next section
                else
                    -- not odoo, enable regular python LSPs
                    vim.lsp.config('ruff', {})
                    vim.lsp.enable("ruff")
                    vim.lsp.config('pyright', {})
                    vim.lsp.enable("pyright")
                end

                -- some lsp bindings I like
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, {})
                vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, {})
                vim.keymap.set('n', 'gl', vim.diagnostic.open_float, {})
                -- reminder of some defaults:
                -- "grn" is mapped in Normal mode to vim.lsp.buf.rename()
                -- "gra" is mapped in Normal and Visual mode to vim.lsp.buf.code_action()
                -- "grr" is mapped in Normal mode to vim.lsp.buf.references()
                -- "gri" is mapped in Normal mode to vim.lsp.buf.implementation()
                -- "gO" is mapped in Normal mode to vim.lsp.buf.document_symbol()
                -- CTRL-S is mapped in Insert mode to vim.lsp.buf.signature_help()

            end,
        },
        {  -- odooLS specific config
            'odoo/odoo-neovim',
            config = function()
                -- still doesn't work for now, but at least it does not actively crash anymore
                if vim.fn.filereadable('odools.toml') == 1 then
                    -- odoo workspace, try to use just odoo-ls
                    vim.lsp.config("odoo_ls", {
                        -- custom config if needed
                        cmd = {
                            -- Path to the odoo_ls_server binary
                            vim.fn.expand('$HOME/src/odoo-ls/server/target/release/odoo_ls_server'),
                            -- '--config-path',
                            -- 'Path_to_toml/odools.toml',
                            '--stdlib',
                            vim.fn.expand('$HOME/src/misc_gists/typeshed/stdlib'),
                        }
                    })
                    vim.lsp.enable({"odoo_ls"})
                else
                    -- not odoo, enable regular python LSPs
                    -- see previous section
                end
            end
        },
        {
            -- code completion menu
            "hrsh7th/cmp-buffer",
            dependencies = {
                { 'hrsh7th/nvim-cmp' },
            },
            lazy = true,
            event = { "BufReadPost", "BufNewFile" },
            config = function()
                local cmp = require('cmp')
                -- local cmp_format = require('lsp-zero').cmp_format({details = true})
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
                    -- formatting = cmp_format,   --TODO do this without lsp-zero
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
    },
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "habamax" } },
    -- automatically check for plugin updates
    checker = { enabled = true },
})
