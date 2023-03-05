if [[ $1 == "base" ]]; then
    echo "Starting base setup"
    echo "###################"
    echo "Keep an eye on this terminal, the scripts may have interractive bits"
    # install homebrew
    echo "Installing Homebrew"
    echo "-------------------"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # desktop apps
    echo "installing desktop apps"
    echo "-----------------------"
    curl -s 'https://api.macapps.link/en/firefox-chrome-torbrowser-bettertouchtool-vscode-docker-iterm-transmission-spectacle-discord' | sh
    # install ohmyzsh
    echo "setting up terminal to use Zsh and oh-my-zsh"
    echo "--------------------------------------------"
    brew install zsh zsh-completions
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    return
fi

if [[ $1 == "step2" ]]; then
    # source the scripts in this repo
    echo "Loading the aliases"
    echo "###################"
    source ../alias_loader.sh


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
