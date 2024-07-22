local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'   -- plugin manager
    -- add plugins here
    use {
        --  an IDE like search interface
        'nvim-telescope/telescope.nvim', tag = '0.1.6',
        -- or                            , branch = '0.1.x',
        requires = {
            { 'nvim-lua/plenary.nvim' },  -- default requirement
            { 'nvim-telescope/telescope-live-grep-args.nvim' }  -- adds ripgrep arguments support to <leader>fg
        },
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- supercharged highlighting
        'nvim-treesitter/nvim-treesitter',
        { run = ':TSUpdate' },
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- extension for treesitter : keep class and function definition within the window
        "nvim-treesitter/nvim-treesitter-context",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- git commands integration
        "tpope/vim-fugitive",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- fugitiv extension : enables :Gbrowse
        "tpope/vim-rhubarb",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- put git diff indication next to the line numbers
        "lewis6991/gitsigns.nvim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- enables :tig within nvim
        "iberianpig/tig-explorer.vim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- highlights in red trailling spaces
        "ntpeters/vim-better-whitespace",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- add indentation markers
        "lukas-reineke/indent-blankline.nvim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- a theme
        "rebelot/kanagawa.nvim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- file explorer
        "nvim-tree/nvim-tree.lua",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- extension for nvim tree: displays nice looking file type icons
        "nvim-tree/nvim-web-devicons",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- cool looking bottom line
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- cool looking command prompt
        "folke/noice.nvim",
        requires = {
            "MunifTanjim/nui.nvim", -- required
            "rcarriga/nvim-notify", -- optional
        }
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    -- LSP
    use {
        -- language server manager
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            -- automate lsp installation
            { 'williamboman/mason.nvim' },
            { 'williamboman/mason-lspconfig.nvim' },
            -- strict dependencies
            { 'neovim/nvim-lspconfig' },
            { 'hrsh7th/nvim-cmp' },
            { 'hrsh7th/cmp-nvim-lsp' },
            { 'L3MON4D3/LuaSnip' },
        },
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    -- completion
    use {
        -- code completion menu
        "hrsh7th/cmp-buffer",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        -- add completion for nvim specific lua
        "hrsh7th/cmp-nvim-lua",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end
end)
