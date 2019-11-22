if [[ "$1" == "base" ]]; then
    # install homebrew
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    # desktop apps
    curl -s 'https://api.macapps.link/en/firefox-chrome-torbrowser-bettertouchtool-vscode-iterm-transmission-spectacle-spotify-vlc-thunderbird-adium' | sh
    # install ohmyzsh
    brew install zsh zsh-completions
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

    return
fi

# source the scripts in this repo
source ../alias_loader.sh

# ODOO SETUP
run 10 echo "############################################"
echo "starting odoo setup"
run 10 echo "############################################"
mkdir -p "$SRC"
cd $SRC
# build odoo universe
git clone git@github.com:odoo/support-tools.git
git clone git@github.com:odoo/odoo.git
git -C $ODOO remote add git@github.com:odoo-dev/odoo.git
git clone git@github.com:odoo/enterprise.git
git -C $ENTERPRISE remote add git@github.com:odoo-dev/enterprise.git
git clone git@github.com:odoo/design-themes.git
git -C $SRC/design-themes remote add git@github.com:odoo-dev/design-themes.git
git clone git@github.com:odoo/internal.git
git clone git@github.com:odoo/documentation-user.git
# build multiverse
mkdir -p "$SRC_MULTI"
cd $SRC_MULTI
mkdir master
cd master
git clone git@github.com:odoo/odoo.git
git -C $SRC_MULTI/odoo checkout master
git clone git@github.com:odoo/enterprise.git
git -C $SRC_MULTI/enterprise checkout master
git clone git@github.com:odoo/design-themes.git
git -C $SRC_MULTI/design-themes checkout master
# build main multiverse branches and virtual env
build_multiverse_branch 13.0
build_odoo_virtualenv 13.0
build_multiverse_branch 12.0
build_odoo_virtualenv 12.0
build_multiverse_branch 11.0
build_odoo_virtualenv 11.0
# TODO install wkhtmltopdf

# setup editors
sh $AP/editors/vim/apply_vimrc.sh
sh $AP/editors/vscode/apply_settings.sh

