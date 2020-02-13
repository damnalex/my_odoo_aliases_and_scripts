##########################################################
########################  PATHS  ##########################
###########################################################

export AP=$(dirname $0)

export SRC="$HOME/src"
export ODOO="$SRC/odoo"
export ENTERPRISE="$SRC/enterprise"
export INTERNAL="$SRC/internal"
export ST="$SRC/support-tools"
export SRC_MULTI="$HOME/multi_src"

if [ "$OSTYPE" = "darwin19.0" ]; then
    export ODOO_STORAGE="$HOME/Library/Application Support/Odoo"
else
    export ODOO_STORAGE="$HOME/.local/Odoo"
fi

# GPG stuff
export GPG_TTY=$(tty)

# activate bash style completion
autoload bashcompinit
bashcompinit

# activate vi mode in the terminal
bindkey -v
if [ ! -f ~/.inputrc ]; then
    echo "set editing-mode vi" > ~/.inputrc
else
    if ! grep -q "set editing-mode vi" ~/.inputrc; then
        echo "set editing-mode vi" >> ~/.inputrc
    fi
fi

# setup .zshrc
if ! grep -q "source $0" ~/.zshrc; then
    echo "source $0" >> ~/.zshrc
fi

# load all the other files in the $AP folder
source $AP/zsh_alias.sh
source $AP/odoo_alias.sh
source $AP/typo.sh
source $AP/completion.sh
