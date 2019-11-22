##############################################
######  "manage this repo"  stuffs  ##########
##############################################

alias e="vim"

reload_zshrc() {
    # don't modify this one from eza to avoid headaches
    source ~/.zshrc
    deactivate > /dev/null 2>&1
}

eza() {
    # edit and reload alias
    local file_to_load=" "
    case $1 in
        zsh)
            file_to_load="zsh_alias.sh"
            ;;
        loader)
            file_to_load="alias_loader.sh"
            ;;
        odoo)
            file_to_load="odoo_alias.sh"
            ;;
        git)
            file_to_load="python_scripts/git_odoo.py"
            ;;
        drop)
            file_to_load="drop_protected_dbs.txt"
            ;;
        typo)
            file_to_load="typo.sh"
            ;;
        compl)
            file_to_load="completion.sh"
            ;;
        vim)
            file_to_load="editors/vim/.vimrc"
            ;;
        "")
            #default
            file_to_load="odoo_alias.sh"
            ;;
        tig)
            ezatig
            return
            ;;
        *)
            echo "zsh_alias.sh --> eza zsh"
            echo "alias_loader.sh --> eza loader"
            echo "odoo_alias.sh --> eza odoo   or   eza"
            echo "drop_protected_dbs.txt --> eza drop"
            echo "git_odoo.py --> eza git"
            echo "typo.py --> eza typo"
            echo "completion.sh --> eza compl"
            echo ".vimrc --> eza vim"
            echo "repo info --> eza tig"
            return
            ;;
    esac
    local current_dir=$(pwd)
    cd $AP
    if [[ $2 == "" ]]; then
        vim $AP/$file_to_load || return
    else
        vim -c "/.*$2.*(" $AP/$file_to_load || return
    fi
    cd "$current_dir"
    source $AP/alias_loader.sh
}

ezatig() {
    local current_dir=$(pwd)
    cd $AP
    tig
    cd "$current_dir"
}

###################################
#########   Misc Stuff  ###########
###################################

alias c='clear'
alias l="ls -lAh"

#history analytics
history_count() {
    history -n | cut -d' ' -f1 | sort | uniq -c | trim | sort -gr | less
}

trim() {
    awk '{$1=$1};1'
}

find_file_with_all() {
    # find_file_with_all [--ext <ext>] <expressions>...
    # list all the files in the current directory and its subdirectories
    # where all the expressions are present
    # looks in the file of type "ext" if --ext is provided
    # looks in py files otherwise
    local ext=""
    local first_word=""
    local other_words_start=0
    if [ "$1" = "--ext" ]; then
        ext=$2
        first_word=$3
        other_words_start=4
    else
        ext="py"
        first_word=$1
        other_words_start=2
    fi
    local cmd="grep -rl $first_word **/*.$ext"
    for word in $@[$other_words_start,-1]; do
        cmd="grep -l $word \$("$cmd")"
    done
    eval $cmd
    # echo "\n\n\nthe commmand that ran : "
    # echo $cmd
}

run() {
    # source https://www.shellhacks.com/linux-repeat-command-n-times-bash-loop/
    number=$1
    shift
    for n in $(seq $number); do
        $@
    done
}

git_fame() {
    local file_to_analyse=$1
    git ls-tree -r -z --name-only HEAD -- ${file_to_analyse} | xargs -0 -n1 git blame --line-porcelain HEAD | grep "^author " | sort | uniq -c | sort -nr
}

# make git_fame callable as "git fame" (as if it was a standard git comand)
git() {
    if [[ $1 == "fame" ]]; then
        git_fame $2
    else
        command git "$@"
    fi
}

sort_and_remove_duplicate() {
    local file=$1
    echo "$(cat $file | sort | uniq)" > $file
}

wait_for_pid() {
    # wait for the process of pid $1 to finish
    while kill -0 "$1" 2> /dev/null; do sleep 0.2; done
}

#########################################
######## system specific stuffs #########
#########################################

if [ "$OSTYPE" = "darwin18.0" ]; then
    # macos
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export PATH="/usr/local/sbin:$PATH"
    alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'

    # monitoring
    alias netdata="netdata_start > /dev/null && open http://localhost:19999"
    alias netdata_start="brew services start netdata"
    alias netdata_stop="brew services stop netdata"

    # end of macos stuffs
else
    # linux

    maj() {
        sudo apt-get update &&
            sudo apt-get upgrade -y &&
            sudo apt-get autoclean &&
            sudo apt-get autoremove -y
    }

    fullmaj() {
        sudo apt-get update &&
            sudo apt-get upgrade -y &&
            sudo apt-get dist-upgrade -y &&
            sudo apt-get autoclean &&
            sudo apt-get autoremove -y
    }

    alias cya='systemctl suspend -i'

    clear_ram() {
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

    noweb() {
        sg no_web $@[1,-1]
    }
    alias ni='noweb'

    # end of linux stuff
fi

##############################################
##############  typo  stuffs  ################
##############################################

new_typo() {
    local typo=$1
    local correct_command=$2
    echo "alias '$typo'='$correct_command'" >> $AP/typo.sh
    reload_zshrc
}

commit_typos() {
    git -C $AP add $AP/typo.sh
    git -C $AP commit -m "[AUTOMATIC] update typos file"
}

##############################################
#############  python  stuffs  ###############
##############################################

new_lib_in_other_python_requirements() {
    local library=$1
    echo "$library" >> $AP/python_scripts/other_requirements.txt
    sort_and_remove_duplicate $AP/python_scripts/other_requirements.txt
}

commit_new_lib_in_other_python_requirements() {
    git -C $AP add $AP/python_scripts/other_requirements.txt
    git -C $AP commit -m "[AUTOMATIC] update other_requirements.txt"
}

##############################################
##############  style stuffs  ################
##############################################

ap_format_files() {
    python3 -m black $AP
    shfmt -l -i 4 -s -ci -sr -w $AP
}
