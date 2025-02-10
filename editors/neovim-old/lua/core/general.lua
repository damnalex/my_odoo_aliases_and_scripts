-- general
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
