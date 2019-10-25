##########################################################
########################  PATHS  ##########################
###########################################################

export SRC="$HOME/src"
export ODOO="$SRC/odoo"
export ENTERPRISE="$SRC/enterprise"
export INTERNAL="$SRC/internal"
export ST="$SRC/support-tools"
export AP=$(dirname $0)
export SRC_MULTI="$HOME/multi_src"

if [ "$OSTYPE" = "darwin18.0" ]; then
    export ODOO_STORAGE="$HOME/Library/Application Support/Odoo"
else
    export ODOO_STORAGE="$HOME/.local/Odoo"
fi

# activate bash style completion
autoload bashcompinit
bashcompinit

source $AP/zsh_alias.sh
source $AP/odoo_alias.sh
source $AP/typo.sh
source $AP/completion.sh
