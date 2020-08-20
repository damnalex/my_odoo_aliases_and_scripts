##############################################
######  "manage this repo"  stuffs  ##########
##############################################

reload_zshrc() {
    # don't modify this one from eza to avoid headaches
    source ~/.zshrc
    deactivate >/dev/null 2>&1
}

alias e="vim"

eza() {
    # edit and reload alias and various scripts
    local file_to_load=" "
    local file_type=""
    case $1 in
    zsh)
        file_to_load="zsh_alias.sh"
        file_type="sh"
        ;;
    loader)
        file_to_load="alias_loader.sh"
        file_type="sh"
        ;;
    odoo)
        file_to_load="odoo_alias.sh"
        file_type="sh"
        ;;
    odoopy)
        file_to_load="python_scripts/odoo_alias.py"
        file_type="py"
        ;;
    git)
        file_to_load="python_scripts/git_odoo.py"
        file_type="py"
        ;;
    drop)
        file_to_load="drop_protected_dbs.txt"
        file_type="other"
        ;;
    typo)
        file_to_load="python_scripts/typo.py"
        file_type="py"
        ;;
    utils)
        file_to_load="python_scripts/utils.py"
        file_type="py"
        ;;
    compl)
        file_to_load="completion.sh"
        file_type="sh"
        ;;
    vim)
        file_to_load="editors/vim/.vimrc"
        file_type="other"
        ;;
    "")
        #default
        file_to_load="odoo_alias.sh"
        file_type="sh"
        ;;
    tig)
        ezatig
        return
        ;;
    *)
        echo "zsh_alias.sh --> eza zsh"
        echo "alias_loader.sh --> eza loader"
        echo "odoo_alias.sh --> eza odoo   or   eza"
        echo "odoo_alias.py --> eza odoopy"
        echo "drop_protected_dbs.txt --> eza drop"
        echo "git_odoo.py --> eza git"
        echo "typo.py --> eza typo"
        echo "completion.sh --> eza compl"
        echo ".vimrc --> eza vim"
        echo "repo info --> eza tig"
        return
        ;;
    esac
    # change the current directory while editing the files to have a better experience with my vim config
    local current_dir=$(pwd)
    cd $AP
    if [[ $2 == "" ]]; then
        vim $AP/$file_to_load || return
    else
        case $file_type in
        sh)
            vim -c "/.*$2.*(" $AP/$file_to_load || return
            ;;
        py)
            vim -c "/def $2" $AP/$file_to_load || return
            ;;
        other)
            vim -c "$2" $AP/$file_to_load || return
            ;;
        esac
    fi
    cd "$current_dir"
    # editing is done, applying changes
    source $AP/alias_loader.sh
}

ezatig() {
    # tig the $AP folder from anywhere
    local current_dir=$(pwd)
    cd $AP
    tig
    cd "$current_dir"
}

# git the $AP repo from anywhere
alias geza="git -C $AP"

###################################
#########   Misc Stuff  ###########
###################################

alias l="ls -lAh"
alias tree="tree -C -a -I '.git'"

history_count() {
    #history analytics
    history -n | cut -d' ' -f1 | sort | uniq -c | trim | sort -gr | less
}

trim() {
    # remove leading and trailling white spaces
    awk '{$1=$1};1'
}

#port killer
listport() {
    # show all process working on port $1
    lsof -i tcp:$1
}
killport() {
    # kill the process working on port $1 (if there are multiple ones, kill only the first one)
    listport $1 | sed -n '2p' | awk '{print $2}' | xargs kill -9
}

find_file_with_all() {
    # SLOW FOR VERY BIG OR DEEP FOLDER
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
    # run a command $1 times back to back
    # source https://www.shellhacks.com/linux-repeat-command-n-times-bash-loop/
    number=$1
    shift
    for n in $(seq $number); do
        $@
    done
}

git_fame() {
    # SLOW FOR VERY BIG REPO
    # show the number of lines attributed to each contributor in file $1, or for all files in folder if no file is provided
    local file_to_analyse=$1
    git ls-tree -r -z --name-only HEAD -- ${file_to_analyse} | xargs -0 -n1 git blame --line-porcelain HEAD | grep "^author " | sort | uniq -c | sort -nr
}

git_last_X_hashes() {
    git log --pretty=format:"%H" | head -n $1
}

git_rebase_and_merge_X_on_Y() {
    # apply the content of branch X onto branch Y
    # does not modify branch X
    git branch | grep tmp_branch_random_name && return 1
    git checkout -b tmp_branch_random_name $1 &&
        git rebase $2 &&
        git rebase $2 tmp_branch_random_name &&
        git branch -D tmp_branch_random_name
}

git_prune_branches() {
    # remove remote branches that don't exist anymore
    # then remove the local branches that don't exists on the repo anymore
    git fetch --prune --all
    git branch -vv | grep ': gone] ' | awk '{print $1}' | xargs git branch -D
}

sort_and_remove_duplicate() {
    # don't use this for very big files as it puts the whole file in memory
    # a more memory efficient alternative would be to use a tmp file, but
    # it was the intended goal of this method to not use a tmp file.
    local file=$1
    echo "$(cat $file | sort | uniq)" >$file
}

wait_for_pid() {
    # wait for the process of pid $1 to finish
    while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
}

#########################################
######## system specific stuffs #########
#########################################

if [ "$OSTYPE" = "darwin19.0" ]; then
    # macos specific stuffs
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export PATH="/usr/local/sbin:$PATH"
    alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'

    # monitoring
    alias netdata="netdata_start > /dev/null && open http://localhost:19999"
    alias netdata_start="brew services start netdata"
    alias netdata_stop="brew services stop netdata"

    # paths to some libraries
    export PKG_CONFIG_PATH="/usr/local/opt/zlib/lib/pkgconfig"

    # end of macos stuffs
fi

##############################################
##############  typo  stuffs  ################
##############################################

new_typo() {
    # open the typo definition file
    eza typo
}

##############################################
#############  python  stuffs  ###############
##############################################

##############################################
##############  style stuffs  ################
##############################################

ap_format_files() {
    # do some automatic style formating for the .py and .sh files of the $AP folder
    python3 -m black $AP
    # shfmt -l -i 4 -s -ci -sr -w $AP
    shfmt -l -i 4 -w $AP
}
