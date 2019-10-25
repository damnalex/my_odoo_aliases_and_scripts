set nocompatible
set number 
set relativenumber

set ignorecase
set smartcase

filetype indent plugin on
set autoindent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smarttab

" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

syntax on
set nowrap

set incsearch
set hlsearch
