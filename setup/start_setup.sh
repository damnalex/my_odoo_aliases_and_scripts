if [[ $1 == "base" ]]; then
    echo "Starting base setup"
    echo "###################"
    echo "Keep an eye on this terminal, the scripts may have interractive bits"
    # install homebrew
    echo "Installing Homebrew"
    echo "-------------------"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    # desktop apps
    echo "installing desktop apps"
    echo "-----------------------"
    curl -s 'https://api.macapps.link/en/firefox-chrome-torbrowser-bettertouchtool-vscode-iterm-transmission-spectacle-spotify-vlc-thunderbird-adium' | sh
    # install ohmyzsh
    echo "setting up terminal to use Zsh and oh-my-zsh"
    echo "--------------------------------------------"
    brew install zsh zsh-completions
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

    return
fi

if [[ $1 = "step2" ]]; then
    # source the scripts in this repo
    echo "Loading the aliases"
    echo "###################"
    source ../alias_loader.sh

    # ODOO SETUP
    run 15 echo " "
    echo "Starting odoo setup"
    echo "###################"
    # echo "Installing required third party libs"
    # echo "------------------------------------"
    # TODO install wkhtmltopdf
    # TODO install all requiered dev libs
    run 15 echo " "
    echo "Building Odoo repos"
    echo "-------------------"
    echo "Starting with the universe"
    echo "°°°°°°°°°°°°°°°°°°°°°°°°°°"
    mkdir -p "$SRC"
    cd $SRC
    git clone git@github.com:odoo/support-tools.git
    git clone git@github.com:odoo/odoo.git
    git -C $ODOO remote add git@github.com:odoo-dev/odoo.git
    git clone git@github.com:odoo/enterprise.git
    git -C $ENTERPRISE remote add git@github.com:odoo-dev/enterprise.git
    git clone git@github.com:odoo/design-themes.git
    git -C $SRC/design-themes remote add git@github.com:odoo-dev/design-themes.git
    git clone git@github.com:odoo/internal.git
    git clone git@github.com:odoo/documentation-user.git
    run 15 echo " "
    echo "Continuing with the multiverse"
    echo "°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°"
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
    run 15 echo " "
    echo "Base setup for multiverse done: building main branches"
    echo "°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°"
    build_multiverse_branch 13.0
    build_multiverse_branch 12.0
    build_multiverse_branch 11.0
    run 15 echo " "
    echo "Main branches of the mutliverse done: building main virtualenvs"
    echo "°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°"
    build_odoo_virtualenv 13.0
    build_odoo_virtualenv 12.0
    build_odoo_virtualenv 11.0

    run 15 echo " "
    echo "Settings up editors"
    echo "###################"
    sh $AP/editors/vim/apply_vimrc.sh
    sh $AP/editors/vscode/apply_settings.sh

    run 15 echo " "
    echo "############################"
    echo "Automated setup has finished"
    echo "############################"
    return
fi


echo "No valid parameter provided, see README.md"

