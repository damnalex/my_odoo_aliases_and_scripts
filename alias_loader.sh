##########################################################
########################  PATHS  ##########################
###########################################################

# this repo
export AP=$(dirname "$0")

export SRC="$HOME/src"
# odoo repos
# export ODOO="$SRC/odoo"
# export ENTERPRISE="$SRC/enterprise"
# export DESIGN_THEMES="$SRC/design-themes"
# export INDUSTRY="$SRC/industry"
export USER_DOC="$SRC/documentation-user"
export SRC_MULTI="$HOME/odoo/versions"
# odoo internal repos
export INTERNAL="$SRC/internal"
export PAAS="$SRC/paas"
export SAAS="$SRC/saas-automation"
export IAP_APPS="$SRC/iap-apps"
export ST="$SRC/support-tools"
export DEVTOOL="$SRC/OdooDevTool"
export UPGR_PLAT="$SRC/upgrade-platform"
export UPGR_UTIL="$SRC/upgrade-util"
export UPGR="$SRC/upgrade"
export PAPER_MUNCHER="$SRC/paper-muncher"
export ODOO_LS="$SRC/odoo-ls"
# third party repo
export ODYSSEY="$SRC/misc_gists/odyssey-gpt"

if [[ $OSTYPE =~ ^darwin ]]; then
    # macos specific stuffs
    export ODOO_STORAGE="$HOME/Library/Application Support/Odoo"
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export PATH="/usr/local/sbin:$PATH"
    # paths to some libraries
    export PKG_CONFIG_PATH="/usr/local/opt/zlib/lib/pkgconfig"
    # misc
    alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
    # paths to gnu version of tools
    export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
    export HOMEBREW_NO_INSTALL_CLEANUP=TRUE
else
    # on linux machine
    export ODOO_STORAGE="$HOME/.local/Odoo"
fi

# GPG stuff
export GPG_TTY=$(tty)

# activate bash style completion
autoload bashcompinit
bashcompinit

# hyphen insensitive completion
zstyle ':completion:*' matcher-list 'm:{-_}={_-}'

# ZSH BASICS (History, Completions, Keybindings)
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt append_history
setopt share_history
setopt hist_ignore_all_dups

autoload -Uz compinit && compinit

# man colorization
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# use neovim as default editor
export EDITOR="nvim"

# activate vi mode in the terminal
bindkey -v
if [ ! -f ~/.inputrc ]; then
    echo "set editing-mode vi" >~/.inputrc
else
    if ! grep -q "set editing-mode vi" ~/.inputrc; then
        echo "set editing-mode vi" >>~/.inputrc
    fi
fi

# re-add emacs style short cut to the command line editor
bindkey '^x^e' edit-command-line

alias ll='ls -lhA'

# setup .zshrc to source this file
if ! grep -q "source $0" ~/.zshrc; then
    echo "source $0" >>~/.zshrc
fi

########################################
######   terminal customizations   #####
########################################

# GIT PROMPT CONFIG
# 1. Load the version control module and run it before every prompt
autoload -Uz vcs_info
precmd_vcs_info() {
    vcs_info
}
precmd_functions+=(precmd_vcs_info)

# 2. Enable git and force it to check for uncommitted/unstaged changes
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true

# 3. Define the symbols for your changes
zstyle ':vcs_info:*' unstagedstr ' %F{red}✗%f' # Red X for unstaged modifications
zstyle ':vcs_info:*' stagedstr ' %F{green}+%f' # Green + for staged changes

# 4. Format the output string
# %b = branch name, %u = unstaged symbol, %c = staged symbol
zstyle ':vcs_info:git:*' formats ' git:(%F{magenta}%b%f%u%c)'
zstyle ':vcs_info:git:*' actionformats ' git:(%F{magenta}%b%f|%a%u%c)'

# 5. Allow Zsh to evaluate variables inside the PROMPT string
setopt PROMPT_SUBST

# 6. Define the final prompt
# ${vcs_info_msg_0_} injects the git string, but stays completely hidden outside of a repo.
PROMPT='%F{green}➜%f %F{blue}%1~%f${vcs_info_msg_0_} '
# PROMPT="$PROMPT ${vcs_info_msg_0_} "

# time in prompt
PROMPT="[%D|%T] $PROMPT"
TMOUT=5
TRAPALRM() {
    # zle reset-prompt
    case "$WIDGET" in
    expand-or-complete | self-insert | up-line-or-beginning-search | down-line-or-beginning-search | backward-delete-char | .history-incremental-search-backward | .history-incremental-search-forward)
        :
        ;;

    *)
        # uncomment this to see the current state of the widget in case of weirdness
        # PROMPT="[$WIDGET]"
        zle reset-prompt
        ;;
    esac
}

##################################################
### load all the other files in the $AP folder ###
##################################################

# compile/generate non-bash aliases
ap_compile() {
    python3 $AP/python_scripts/alias.py --generate
}

# pure shell functions and aliases
source $AP/alias.sh

# vendored functions
source $AP/vendored.sh

# used to be in oh myt zsh
source $SRC/misc_gists/zsh-autosuggestions/zsh-autosuggestions.zsh
source $SRC/misc_gists/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# load python based functions and aliases
if [ ! -f $AP/autogenerated_scripts.sh ]; then
    ap_compile
fi
source $AP/autogenerated_scripts.sh

# load autocompletion scripts
source $AP/completion.sh
source $ST/scripts/completion/oe-support-completion.sh
complete -o default -F _oe-support oes
source $ST/scripts/completion/clean-database-completion.sh
complete -o default -F _clean-database clean_database
source /Users/alex/src/support-tools/scripts/completion/find_backup_completion.sh
complete -o default -F _find_backup find_backup

# load temporary scripts
# this file may be deleted at any time, so we need to make sure that it actually exists before trying to source it
if [ -f $AP/temporary-scripts.sh ]; then
    source $AP/temporary-scripts.sh
fi

##################################################
###            Finishing touches               ###
##################################################
# scripts / alias defined in this repo to call at each terminal startup

gov 18.0
