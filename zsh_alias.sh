##############################################
############  personnal stuffs  ##############
##############################################

maj(){
    sudo apt-get update && 
    sudo apt-get upgrade -y && 
    sudo apt-get autoclean && 
    sudo apt-get autoremove -y
}

fullmaj(){
    sudo apt-get update &&
    sudo apt-get upgrade -y &&
    sudo apt-get dist-upgrade -y &&
    sudo apt-get autoclean &&
    sudo apt-get autoremove -y
}

alias reload_zshrc='source ~/.zshrc'

alias cya='systemctl suspend -i'

clear_ram(){
    echo "This is going to take a while ..." && 
    echo "Droppping cache" && 
    sudo su -c "echo 3 > /proc/sys/vm/drop_caches" root && 
    echo "Cache dropped" && 
    echo "turning swap off" && 
    sudo swapoff -a && 
    echo "turning swap back on" && 
    sudo swapon -a && 
    echo "Aaaaaand... done!" 
}

noweb(){
        sg no_web $@[1,-1]
}
alias ni='noweb'


#############################################
#############  zsh stuffs  ##################
#############################################

alias e="vim"

eza(){
    era vim $1
}

geza(){
    era gedit $1
}

era(){
    # edit and reload alias
    # era [vim|gedit] the_alias_file_to_edit
    local file_to_load=" "
    case $2 in
        zsh)
            file_to_load="zsh_alias.sh"
            ;;
        loader)
            file_to_load="alias_loader.sh"
            ;;
        odoo)
            file_to_load="odoo_alias.sh"
            ;;
        --help)
            echo "zsh_alias.sh --> (g)eza zsh"
            echo "alias_loader.sh --> (g)eza loader"
            echo "odoo_alias.sh --> (g)eza odoo   or   (g)eza"
            return
            ;;
        *)
            #default
            file_to_load="odoo_alias.sh"
            ;;
    esac

    if [ "$1" = "vim" ]
    then
        e $AP/$file_to_load &&
        reload_zshrc
    else
        gedit $AP/$file_to_load &&
        reload_zshrc
    fi
}








#history analytics
history_count(){
    history -n | cut -d' ' -f1 | sort | uniq -c | trim | sort -gr | less
}
trim(){
    awk '{$1=$1};1'
}


#########################################
######## system specific stuffs #########
#########################################

if [ "$OSTYPE" = "darwin18.0" ]
then
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    alias gedit='/usr/local/Cellar/gedit/3.30.2/bin/gedit'
    alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
fi
