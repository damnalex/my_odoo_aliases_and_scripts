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
    }
    use {
        -- supercharged highlighting
        'nvim-treesitter/nvim-treesitter',
        { run = ':TSUpdate' },
    }
    use {
        -- extension for treesitter : keep class and function definition within the window
        "nvim-treesitter/nvim-treesitter-context",
    }
    use {
        -- git commands integration
        "tpope/vim-fugitive",
    }
    use {
        -- fugitiv extension : enables :Gbrowse
        "tpope/vim-rhubarb",
    }
    use {
        -- put git diff indication next to the line numbers
        "lewis6991/gitsigns.nvim",
    }
    use {
        -- highlights in red trailling spaces
        "ntpeters/vim-better-whitespace",
    }
    use {
        -- add indentation markers
        "lukas-reineke/indent-blankline.nvim",
    }
    use {
        -- a theme
        "rebelot/kanagawa.nvim",
    }
    use {
        -- file explorer
        "nvim-tree/nvim-tree.lua",
    }
    use {
        -- extension for nvim tree: displays nice looking file type icons
        "nvim-tree/nvim-web-devicons",
    }
    use {
        -- cool looking bottom line
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    }
    use {
        -- cool looking command prompt
        "folke/noice.nvim",
        requires = {
            "MunifTanjim/nui.nvim", -- required
            "rcarriga/nvim-notify", -- optional
        }
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
    }
    -- completion
    use {
        -- code completion menu
        "hrsh7th/cmp-buffer",
    }
    use {
        -- add completion for nvim specific lua
        "hrsh7th/cmp-nvim-lua",
    }

    -- -- odoo LSP
    -- use {
    --     'whenrow/odoo-ls.nvim',
    --     requires = { {'neovim/nvim-lspconfig'} }
    -- }

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
        require('packer').sync()
    end
end)
