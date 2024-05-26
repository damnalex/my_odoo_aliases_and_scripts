set nocompatible

" visual stuff
set ruler  "Show the line and column number of the cursor position at the bottom right corner
set number  "Show the line numbers
set relativenumber  "show lines numbers above and below as relative jumps
set cursorline  "underline the current line, helps find the cursor
syntax enable  "enable syntaxe highlight
set nowrap  "don't wrap long lines
set scrolloff=5  "don't let the cursor be at the very top or very bottom of the screen, helps have enough code context at all time
set lazyredraw  "don't redraw the screen during macros --> makes them a slightly bit faster I guess ?
set showcmd
" colorscheme default
" colorscheme darkblue
" colorscheme elflord
" colorscheme codedark

" uncomment this if ntpeters/vim-better-whitespace is not installed
" set list
" set listchars=tab:~-,trail:.,extends:>,precedes:<
" if (v:version >= 700) && ((&termencoding == "utf-8") || has("gui_running"))
" 	set listchars=tab:»·,trail:·,extends:>,precedes:<,nbsp:=
" endif

" sound stuff
set noerrorbells  "no dings, the ding is bad and useless

" search stuff
set ignorecase  "case insensitiv search
set smartcase   "but not too insensitiv
set incsearch  "show the search results as I type
set hlsearch  "underline the search results
" show subsequent search results in the middle of the screen
nnoremap n nzz
nnoremap N Nzz
nnoremap * *zz
nnoremap # #zz
nnoremap g* g*zz
nnoremap g# g#zz

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

" Fuzzy finding
set path+=**  "only works well if vim was opened for the root of the relevant folder structure

" better command line completion
set wildmenu

" netrw stuffs --> that's for when I do :Explore
" let g:netrw_banner=0        "disables anoying banner
" let g:netrw_browse_split=4  " open in prior window
" let g:netrw_altv=1          " open split to the right
let g:netrw_liststyle=3     " tree view
" let g:netrw_list_hide=netrw_gitignore#Hide()
" let g:netrw_list_hide.=',\(^\|\s\s\)\zs\.\S\+'    " hide dotfiles

" sometime my pinky finger is tired
imap jkjk <Esc>
imap jjj <Esc>
imap kkk <Esc>
" (or I forget to leave insert mode before moving around)

" things from 'dougblack.io/words/a-good-vimrc.html'
" -------------------------------------------------
" remap leader. by default it is a '\'
let mapleader=" "
" turn off search highlight
nnoremap <leader><space> :nohlsearch<CR>
" highlight last inserted text
nnoremap gV `[v`]

" things from 'https://nvie.com/posts/how-i-boosted-my-vim/'
" ---------------------------------------------------------
set hidden      " hide buffers instead of closing them.
                " This way I am not forced to write or discard
                " changes before :e for :find
                " If I try to close vim from the other buffers, I am simply
                " brought back to the non saved buffer (after an error
                " message)

" Easy window navigation
" map <C-h> <C-w>h
" map <C-j> <C-w>j
" map <C-k> <C-w>k
" map <C-l> <C-w>l

" language specific settings
let python_highlight_numbers = 1

" git stuff
autocmd FileType gitcommit setlocal spell spelllang=en_us

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
Plug 'airblade/vim-gitgutter'
Plug 'itchyny/lightline.vim'
Plug 'tomtom/tcomment_vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'ntpeters/vim-better-whitespace'
Plug 'tpope/vim-fugitive'
Plug 'jam1garner/vim-code-monokai'
Plug 'editorconfig/editorconfig-vim'
call plug#end()
" run :source ~/.vimrc  to reload vimrc
" run :PlugInstall to install declared plugins
" run :PlugClean to uninstall undeclared plugins

" vim-gitgutter
set updatetime=100 " this is not a setting specific to gitgutter but necessary for it to be responsive

" lightline
set laststatus=2 " this is not a setting specific to lightline but necessary for it to be active in mono-window mode

" vim-indent-line
let g:indent_guides_guide_size = 1
let g:indent_guides_color_change_percent = 3
let g:indent_guides_enable_on_vim_startup = 1

" ##################################
" ######    Temporary Test  ########
" ##################################

" hardmode - disable hjkl to force me to use other moves more often
" noremap h <NOP>
" noremap j <NOP>
" noremap k <NOP>
" noremap l <NOP>
