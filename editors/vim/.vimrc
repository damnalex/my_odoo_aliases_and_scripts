set nocompatible

" visual stuff
set ruler
set number
set relativenumber
set cursorline
syntax on
set nowrap

" search stuff
set ignorecase
set smartcase
set incsearch
set hlsearch

" tab stuff
filetype indent plugin on
set autoindent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smarttab

" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

" ###################################
" ######     Plugins Zone    ########
" ###################################

" auto install plugged
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" plugin install
call plug#begin('~/.vim/plugged')
Plug 'yuttie/comfortable-motion.vim'
Plug 'airblade/vim-gitgutter'
Plug 'itchyny/lightline.vim'
Plug 'tomtom/tcomment_vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'ntpeters/vim-better-whitespace'
Plug 'tpope/vim-fugitive'
call plug#end()

" plugin config
" comfortable-motion
let g:comfortable_motion_friction = 400.0
let g:comfortable_motion_air_drag = 1.0
let g:comfortable_motion_impulse_mulitplier = 1.5

" vim-gitgutter
set updatetime=100 " this is not a setting specific to gitgutter but necessary for it to be responsive

" lightline
set laststatus=2 " this is not a setting specific to lightline but necessary for it to be active in mono-window mode

" vim-indent-line
colorscheme default " vim-indent-line requires a theme to bet set
let g:indent_guides_guide_size = 1
let g:indent_guides_color_change_percent = 3
let g:indent_guides_enable_on_vim_startup = 1

