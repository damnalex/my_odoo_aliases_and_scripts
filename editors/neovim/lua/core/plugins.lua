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
    use 'wbthomason/packer.nvim'
    -- add plugins here
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.6',
        -- or                            , branch = '0.1.x',
        requires = { { 'nvim-lua/plenary.nvim' } },
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        'nvim-treesitter/nvim-treesitter',
        { run = ':TSUpdate' },
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "nvim-treesitter/nvim-treesitter-context",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "tpope/vim-fugitive",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "tpope/vim-rhubarb",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "airblade/vim-gitgutter",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "iberianpig/tig-explorer.vim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "ntpeters/vim-better-whitespace",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "lukas-reineke/indent-blankline.nvim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "rebelot/kanagawa.nvim",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "nvim-tree/nvim-tree.lua",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
        "nvim-tree/nvim-web-devicons",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    -- LSP
    use {
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
        "hrsh7th/cmp-buffer",
        -- cond = function()
        --     return vim.g.vscode == nil
        -- end,
    }
    use {
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
