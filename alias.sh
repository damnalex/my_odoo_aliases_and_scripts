##############################################
######  "manage this repo"  stuffs  ##########
##############################################

reload_zshrc() {
    # don't modify this one from eza to avoid headaches
    ap_compile
    source ~/.zshrc

}

alias e="nvim"

eza() {
    # edit and reload alias and various scripts
    local file_to_load=" "
    local file_type=""
    case $1 in
    shell)
        file_to_load="alias.sh"
        file_type="sh"
        ;;
    loader)
        file_to_load="alias_loader.sh"
        file_type="other" # to match on non function declaration tokkens
        ;;
    py)
        file_to_load="python_scripts/alias.py"
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
    nvim)
        file_to_load="editors/neovim/init.lua"
        file_type="other"
        ;;
    tmp)
        file_to_load="temporary-scripts.sh"
        file_type="sh"
        ;;
    tig)
        ezatig
        return
        ;;
    typo)
        eza py typos_and_simple_aliases
        return
        ;;
    .)
        # open this repo rather than a specific file in it
        file_to_load="."
        file_type="other"
        ;;
    *)
        echo "eza shell --> alias.sh"
        echo "eza loader --> alias_loader.sh"
        echo "eza compl --> completion.sh"
        echo "eza py --> alias.py"
        echo "eza git --> git_odoo.py"
        echo "eza drop --> drop_protected_dbs.txt"
        echo "eza vim --> vim config"
        echo "eza tmp --> temporary-scripts.sh"
        echo "eza tig --> repo info"
        return
        ;;
    esac
    # open vim with an option prepared search
    local search_cmd=""
    if [[ $2 != "" ]]; then
        case $file_type in
        sh)
            search_cmd='-c "/.*$2.*("'
            ;;
        py)
            search_cmd='-c "/def $2"'
            ;;
        other)
            search_cmd='-c "/$2"'
            ;;
        esac
    fi
    # change the current directory while editing the files to have a better experience with my vim config
    local current_dir=$(pwd)
    cd $AP
    local state_before="$(git status) $(git diff)"
    local skip_reload="No"
    eval "e $search_cmd $AP/$file_to_load" || skip_reload="Yes"
    local state_after="$(git status) $(git diff)"
    cd "$current_dir"
    # if vim exits with an error (existing with :cq for example) do not reload
    # this can speed things up a bit especially if I use `eza` many times in a given tab
    # (not sure why, but each reload gets longer and longer)
    [[ $skip_reload == "Yes" ]] && return
    # reload the shell reload only if there is a change
    local hash_before=$(md5 -q -s $state_before)
    local hash_after=$(md5 -q -s $state_after)
    [[ $hash_after == $hash_before ]] && return
    # editing is done, applying changes
    echo "some changes occured, reloading the shell"
    reload_zshrc
}

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
    if [[ $1 == "-C" ]]; then
        local repo=$2
        shift 2
    else
        local repo=$(pwd)
    fi
    #
    local file_to_analyse=$1
    git -C $repo ls-tree -r -z --name-only HEAD -- ${file_to_analyse} | xargs -0 -n1 git -C $repo blame --line-porcelain HEAD | grep "^author " | sort | uniq -c | sort -nr
}

git_last_X_hashes() {
    if [[ $1 == "-C" ]]; then
        local repo=$2
        shift 2
    else
        local repo=$(pwd)
    fi
    #
    git -C $repo rev-list -n $1 HEAD | tac
}

git_rebase_and_merge_X_on_Y() {
    # apply the content of branch X onto branch Y
    # does not modify branch X
    if [[ $1 == "-C" ]]; then
        local repo=$2
        shift 2
    else
        local repo=$(pwd)
    fi
    #
    git -C $repo branch | grep tmp_branch_random_name && return 1
    git -C $repo checkout -b tmp_branch_random_name $1 &&
        git -C $repo rebase $2 &&
        git -C $repo rebase $2 tmp_branch_random_name &&
        git -C $repo branch -D tmp_branch_random_name
}

git_prune_branches() {
    # remove local reference to remote branches that don't exist anymore
    # then remove the local branches that don't exists on the remote ANYMORE
    local repo=${1:-$(pwd)}
    echo "gc [$repo]..."
    git -C $repo gc --quiet
    echo "fetch prune [$repo]..."
    git -C $repo fetch --prune --all --quiet
    echo "deleting old branches [$repo]..."
    git -C $repo branch -vv | grep ': gone] ' | awk '{print $1}' | xargs git -C $repo branch -D
}

git_push_to_all_remotes() {
    if [[ $1 == "-C" ]]; then
        local repo=$2
        shift 2
    else
        local repo=$(pwd)
    fi
    #
    git -C $repo remote | xargs -L1 -I R git -C $repo push R $@
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

rename_underscore() {
    # rename all the file in the current directory that have space in them
    # to use underscore instead.
    for file in *' '*; do
        if [ -e "${file// /_}" ]; then
            printf >&2 '%s\n' "Warning, skipping $file as the renamed version already exists"
            continue
        fi

        mv -- "$file" "${file// /_}"
    done
}

retry_rsync() {
    # a simple wrapper around rsync that will relaunch it as long as the work is not done
    # usefull for very long running rsyncs where the network could potentially be lost at some point
    # and where I'm not monitoring the progress (overnight for example)
    local finished='No'
    while [[ $finished == 'No' ]]; do
        rsync $@ && finished='Yes'
        sleep 3 # This is to allow manual abort
    done
}

lldu() {
    # a combination of ls -rt and du -sh *
    # shows the creation date and the actual folder size
    # TODO : accept a flag to sort on date, size or name (+ revert)
    # Would probably be easier as a python script in that case
    ll -rt | grep -v '^total' | while read line; do
        local t=$(echo $line | awk '{print $6, $7, $8}')
        local s=$(echo $line | awk '{print substr($0, index($0,$9))}' | sed 's/ /\\ /g' | xargs du -sh)
        echo "$t \t $s"
    done
    echo "Total: $(du -sh . | awk '{print $1}')"
}

fix_dbd() {
    echo "unplug external drive"
    echo "(press enter when ready)"
    read ready
    sudo rm -r /Volumes/Lokhlass*
    echo "you can plug exterenal drive back in"
}

eject_dbd() {
    [[ $(pwd) =~ ^/Volumes/Lokhlas ]] && cd # move out of the folder i'm trying to eject
    for v in /Volumes/Lokhlas*; do
        diskutil eject "$v"
    done
}

##############################################
#############  python  stuffs  ###############
##############################################

##############################################
##############  style stuffs  ################
##############################################

ap_format_files() {
    # do some automatic style formating for the .py and .sh files of the $AP folder
    python3 -m ruff format $AP
    # shfmt -l -i 4 -s -ci -sr -w $AP
    shfmt -l -i 4 -w $AP
}

###########################################################
######################  Odoo stuffs #######################
###########################################################

ssho() {
    # connect to odoo servers
    echo "Connecting to tmux"
    echo "---------------------------"
    ssh -o "StrictHostKeyChecking no" $1.odoo.com -t 'tmux new -t0' && return
    echo "---------------------------"
    echo " fall back: Connecting to Screen"
    echo "---------------------------"
    ssh -o "StrictHostKeyChecking no" $1.odoo.com -t 'screen -rx' && return
    echo "---------------------------"
    echo " fall back: standard ssh connection"
    echo "---------------------------"
    ssh odoo@$1.odoo.com && return
    if [[ $1 = "test.upgrade" ]] || [[ $1 = "upgrade" ]]; then
        echo '\n\n\n\n\n `sudo odoo-upgrade-get-request <request_id>` to get the dump\n\n\n\n\n\n\n'
        ssh mao@test.upgrade.odoo.com -A && return
    fi
}

# git stuffs
alias git_odoo="$AP/python_scripts/git_odoo.py"

# pythonable
go_update_and_clean_all_branches() {
    # go through all main branches of the universe and mutliverse and pull them
    # It also checks for new modules using the our_module_generator helper
    echo "updating universe and multiverse in parallel, weird looking logs incoming!"
    update_all_multiverse_branches &
    git_odoo pull --all &
    wait
    # the full prune is quite slow and doesn't really need to be be run every time
    # Do it only every tenth time (on average)
    [ $((($RANDOM % 10))) -eq 0 ] && go_prune_all || echo 'no pruning this time'
    echo "updating 'our_modules' list:"
    local current_working_dir=$(pwd)
    our_modules_update_and_compare
    cd $current_working_dir
    echo "finishing with a bit of cleanup..."
    clear_pyc --all 2>/dev/null
    run 5 echo "#############################"
    echo "updated and cleaned all branches of multiverse and universe"
}

# pythonable
go_prune_all() {
    # git prune (ish) on all the repos of the the universe, multiverse, platforms and support tools
    echo "----"
    echo "pruning the universe and the multiverse (in parallel, let's get reading for some nasty logs!)"
    local repos=("$ST" "$INTERNAL" "$PAAS" "$UPGR_PLAT")
    for repo in $repos; do {
        git_prune_branches $repo &
    } done
    repos=("odoo" "enterprise" "design-themes")
    for repo in $repos; do {
        git -C "$SRC_MULTI/master/$repo" worktree prune &
        git_prune_branches "$SRC_MULTI/master/$repo" &
    } done
    wait
    echo "----"
    echo "All repos have been pruned"
}

golist() {
    # list all the main source folder repos, theire currently checked out branches and theire status
    git_odoo list
    # (go_fetch >/dev/null 2>&1 &)
}

# this is to fetch everytime a terminal is loaded, or sourced, so it happens often
# `&` is especially important here

_db_version() {
    # get the version on an odoo DB
    psql -tAqX -d $1 -c "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base';"
}

# pythonable
oes() {
    # start oe-support, with some smartness
    if [[ $1 == "raw" ]]; then
        shift
    else
        # -- old way
        # TODO: remove this if the new way works
        # if [[ $1 == "fetch" ]] && ! [[ $* == *'--no-start'* ]]; then
        #     # running first a fetch without starting the db
        #     # then running a separate start to automagically
        #     # use the right virtual-env, even when the db version
        #     # is not known beforehand
        #     echo "oes $@ --no-start "
        #     eval oes $@ --no-start
        #     echo " oes start $@[2,-1] "
        #     eval oes start $@[2,-1]
        #     return
        # fi

        # --new way
        if [[ $1 == "fetch" ]]; then
            go_venv $(o_ver $2 --short)
        fi
        if [[ $1 == "start" ]] || [[ $1 == "restore" ]]; then
            local version=$(_db_version $(list_db_like "%$2")) 2>/dev/null
            if [[ $version != "" ]]; then
                go_venv $version
            fi
        fi
    fi
    # start odoo support
    # echo " $ST/oe-support.py $@ "
    eval $ST/oe-support.py $@
    # (clear_pyc &)
}
# source $ST/scripts/completion/oe-support-completion.sh
# complete -o default -F _oe-support oes

odef() {
    # download restore and start in one command with odev
    local dbname=$1
    local dburl=${2:-"$dbname.odoo.com"}
    odev quickstart $dbname $dburl --stop-after-init
    odev run $dbname
}

# pythonable
droplike() {
    # drop the DBs with the given patern (sql style patern)
    local dbs_list=$(list_db_like $1 | tr '\n' ' ')
    if [ -z $dbs_list ]; then
        echo "no DB matching the given pattern were found"
    else
        eval dropodoo $dbs_list
    fi
}

dropall_odoo() {
    # drop all odoo DBs
    local where_clause="where t1.datname not like 'CLEAN_ODOO%' "
    for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 $where_clause ORDER BY LOWER(t1.datname);"); do
        local db_version=$(_db_version $db_name 2>/dev/null)
        if [ "$db_version" != "" ]; then #ignore non-odoo DBs
            dropodoo $db_name
        fi
    done
}

build_multiverse_branch() {
    # create a new mutliverse branche in $SRC_MULTI
    build_odoo_virtualenv $1
}

update_multiverse_branch() {
    # git pull the repos of the given mutliverse branche

    for repo in 'odoo' 'enterprise' 'design-themes' 'industry'; do
        git -C $SRC_MULTI/$1/$repo pull --quiet && echo "pulled $repo $1 (multiverse)"
    done
}

update_all_multiverse_branches() {
    # git pull the repos of all the multivers branches

    for version in $(ls $SRC_MULTI); do
        update_multiverse_branch $version
    done
}

build_odoo_virtualenv() {
    if [[ $1 == "master" ]]; then
        deactivate 2>/dev/null
        virtualenv --clear "$SRC_MULTI/master/venv"
        pip install -r $SRC_MULTI/master/odoo/requirements.txt
    else
        # setup git worktrees
        oe-support worktree add $1
        git -C $SRC_MULTI/master/industry worktree add $SRC_MULTI/$1/industry $1
        # setup the base virtual env
        deactivate 2>/dev/null
        virtualenv --clear "$SRC_MULTI/$1/venv" #TODO: use recommended python version per odoo version
        pip install -r "$SRC_MULTI/$1/odoo/requirements.txt"
    fi
    ln -s $SRC "$SRC_MULTI/$1/src"
    go_venv $1
    pip install --upgrade pip
    # support specific requirements
    cp $ST/requirements.txt /tmp/requirements.txt
    sed -i "" "/psycopg2/d" /tmp/requirements.txt
    pip install -r /tmp/requirements.txt
    pip install -r $PSS/requirements.txt
    # adding my custom requirements (includes psycopg2-binary)
    pip install -r $AP/python_scripts/requirements.txt
    pip install -r $AP/python_scripts/other_requirements.txt
    deactivate
}

rebuild_virtualenvs() {
    # recreate the main virtual envs
    # usefull when I add something to other_requirements.txt
    for version in $(ls $SRC_MULTI); do {
        echo "--> $version"
        build_odoo_virtualenv $version
    }; done
}

go_venv() {
    # use the virtual env of the given odoo version
    deactivate 2>/dev/null
    if [[ $# -eq 1 ]]; then
        local version=$1
        source $SRC_MULTI/$version/venv/bin/activate &&
            echo "virtualenv for $version activated"
    else
        echo "no virtualenv name provided, falling back to standard python env"
    fi
}

go_venv_current() {
    # use the virtualenv for the currently checked out odoo branch
    echo "THIS FUNCTION CANNOT WORK ANYMORE WITHOUT A FULL UNIVERSE SETUP !!!!!"
    return
    go_venv $(git_branch_version $ODOO)
}

#local-saas
# pythonable
build_local_saas_db() {
    echo "THIS FUNCTION CANNOT WORK ANYMORE WITHOUT A FULL UNIVERSE SETUP !!!!!"
    return
    # create or modify a DB to make it run as if it was a DB on the saas
    local db_name=$1
    godb $db_name
    if [ -f $ODOO/odoo-bin ]; then
        eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $db_name -i saas_trial,project --stop-after-init $@[2,-1]
    else
        eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $db_name -i saas_trial,project --stop-after-init $@[2,-1]
    fi
    local db_uuid=$(psql -tAqX -d $db_name -c "SELECT value FROM ir_config_parameter WHERE key = 'database.uuid';")
    echo $db_uuid
    echo "INSERT INTO databases (name, uuid, port, mode, extra_apps, create_date, expire_date, last_cnx_date, cron_round, cron_time, email_daily_limit, email_daily_count, email_total_count, print_waiting_counter, print_counter, print_counter_limit) VALUES ('$db_name', '$db_uuid', 8069, 'trial', true, '2018-05-23 09:33:08.811069', '2040-02-22 23:59:59', '2018-06-28 13:44:03.980693', 0, '2018-09-21 00:40:28', 30, 10, 0, 0, 0, 10)" | psql meta
}

# pythonable
start_local_saas_db() {
    echo "THIS FUNCTION CANNOT WORK ANYMORE WITHOUT A FULL UNIVERSE SETUP !!!!!"
    return
    # start a local db as if it was on the saas, need to run build_local_saas_db first
    local db_name=$1
    godb $db_name
    local_saas_config_files_set &&
        if [ -f $ODOO/odoo-bin ]; then
            eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name --db-filter=^$db_name$ $@[2,-1]
        else
            eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name $@[2,-1]
        fi
    local_saas_config_files_unset
}

# pythonable
local_saas_config_files_set() {
    # modify the source code of internal to allow me to run db with start_local_saas_db
    sed -i "" "s|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.nip.io:8369'|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial'):|if not has_role('trial') and False: #tempcomment|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|assert isnamedtuple(db)|#assert isnamedtuple(db) #tempcomment|" $INTERNAL/default/saas_worker/metabase.py
}

# pythonable
local_saas_config_files_unset() {
    # fix what was done with local_saas_config_files_set
    sed -i "" "s|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.nip.io:8369'|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial') and False: #tempcomment|if not has_role('trial'):|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|#assert isnamedtuple(db) #tempcomment|assert isnamedtuple(db)|" $INTERNAL/default/saas_worker/metabase.py
}

# pythonable
list_local_saas() {
    # list the DB that were SAASifyied
    echo "Below, the list of local saas DBs"
    psql -d meta -c "SELECT name, id FROM databases ORDER BY id;" -q
    echo "to start --> start_local_saas_db db-name"
    echo "to create a new one --> build_local_saas_db db-name"
    echo "to drop --> dropodoo db-name"
}

#psql aliases
# pythonable
pl() {
    # list odoo DBs
    #echo "select t1.datname as db_name, pg_size_pretty(pg_database_size(t1.datname)) as db_size from pg_database t1 order by t1.datname;" | psql postgres
    local where_clause="where t1.datname not like 'CLEAN_ODOO%' "
    if [ $# -eq 1 ]; then
        where_clause="where t1.datname like '%$1%'"
    fi
    for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 $where_clause ORDER BY LOWER(t1.datname);"); do
        local db_version=$(_db_version $db_name 2>/dev/null)
        if [ "$db_version" != "" ]; then #ignore non-odoo DBs
            local db_size=$(psql -tAqX -d $db_name -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" 2>/dev/null)
            local filestore_size=$(du -sh $ODOO_STORAGE/filestore/$db_name 2>/dev/null | awk '{print $1}')
            echo "$db_version:    \t $db_name \t($db_size + $filestore_size)"
        fi
    done
}

# pythonable
lu() {
    # list the users of DB $1 and copy the username of the admin in the clipboard
    psql -d $1 -c "SELECT login FROM res_users where active = true ORDER BY id LIMIT 1;" -tAqX | pbcopy
    psql -d $1 -c "SELECT id, login FROM res_users where active = true ORDER BY id;" -q
}

# pythonable
list_db_like() {
    # list the DBs with a name that match the pattern (sql like style)
    psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 WHERE t1.datname like '$1' ORDER BY LOWER(t1.datname);"
}

# pythonable
db_age() {
    # tels the age of a given DB
    local db_name=$1
    local query="SELECT datname, (pg_stat_file('base/'||oid ||'/PG_VERSION')).modification FROM pg_database WHERE datname LIKE '$db_name'"
    psql -c "$query" -d postgres
}

export POSTGRES_LOC="$HOME/Library/Application Support/Postgres/var-16"
pgbadger_compute() {
    # create the pgbadger result from $POSTGRES_LOC into pgbdager_output.html
    pgbadger -o /tmp/pgbadger_output.html "$POSTGRES_LOC/postgresql.log" && open /tmp/pgbadger_output.html
}

pgbadger_clean() {
    # empty the postgresql logs
    echo "" >"$POSTGRES_LOC/postgresql.log"
}

test-dump() {
    # test dump (in the current folder, by default) for safety
    local dump_parent_folder=${2:-$(pwd)}
    local dump_f=$dump_parent_folder/dump.sql
    $PSS/test_dump_safety.py $dump_f || return 1
    echo "Safety check OK"
    # create a DB using the dump.sql file in the current folder
    local db_name="$1-test"
    createdb $db_name || return 1
    echo "building DB"
    psql -d $db_name <$dump_f &>/dev/null || return 1
    # neutralize db for local testing
    $ST/lib/neuter.py $db_name --filestore || $ST/lib/neuter.py $db_name
    # start the database just long enough to check if there are custom modules
    # "does it even start" check
    # odev run -y $db_name --stop-after-init --limit-memory-hard 0
    # check for custom modules
    local db_version=$(psql -tAqX -d $db_name -c "select replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') from ir_module_module where name='base'")
    python3 <(curl -s 'https://raw.githubusercontent.com/mao-odoo/all_standard_odoo_apps_per_version/main/is_my_module_standard.py') $db_version -m $(psql -tAqX -d $db_name -c "SELECT name from ir_module_module where state not in ('uninstalled', 'uninstallable');") | grep -A100 "Third-party Modules"
    echo "------------"
    # show DB version and size
    pl | grep $db_name
}

dump_to_sql() {
    # transform a postgres .dump file in a .sql file
    local dump_file=${1:-'no file'}
    local sql_file=${2:-'dump.sql'}
    if [[ "$dump_file" == "no file" ]]; then
        echo "dump_to_sql <source.dump> [<destination.sql>]"
        echo "<destination.sql> defaults to dump.sql"
        return 1
    fi
    pg_restore -f - $1 >$sql_file
}

sql_to_dump() {
    # transform a postgres .sql file in a .dump file
    local sql_file=${1:-'dump.sql'}
    local dump_file=${2:-'dump.dump'}
    if [ -f "$sql_file" ]; then
        createdb xoxo_to_delete &&
            psql -d xoxo_to_delete <$sql_file >/dev/null &&
            pg_dump -F c -f $2 xoxo_to_delete &&
            dropdb xoxo_to_delete
    else
        echo "sql_to_dump [<source.sql>] [<destination.dump>]"
        echo "<source.sql> defaults to dump.sql"
        echo "<destination.dump> defaults to dump.dump"
        return 1
    fi
}

public_file_server_autokill() {
    # start a file server at the current location
    # create a cloudflare tunnel to it
    # kill both when cloudflare tunnel receives a termination signal
    args=("$@")
    ELEMENTS=${#args[@]}
    if [[ $ELEMENTS -ge 2 ]]; then
        # with authentication
        file_server $@ &
    else
        # without authentication
        python3 -m http.server &
    fi
    # checking that the file server is properly running
    sleep 2
    local PY_SERV_PID="$(listport 8000 | sed -n '2p' | awk '{print $2}')"
    kill -0 "${PY_SERV_PID:-111111111111}" 2>/dev/null || return 1 # lets hope I never stumble upon that PID
    # opening the tunnel
    cloudflared tunnel --url http://localhost:8000
    # killing the file server, this line is reached
    # only once a termination signal has been sent to cloudflared
    killport 8000
}

odoo_alive_check() {
    # check for an odoo database to come back online
    local db_url=${1:-'www.odoo.com'}
    clear
    echo "waiting for $db_url to come back since:"
    date
    while ! o_ver $db_url 2>/dev/null; do
        sleep 10
    done
    echo "$db_url is back online since:"
    date
}

compile_odoo_ls() {
    local version=${1:-'latest'}
    if [[ $version == "latest" ]]; then
        version=$(gh api https://api.github.com/repos/odoo/odoo-ls/releases | jq -r '.[0].tag_name')
    fi
    local current_dir=$(pwd)
    cd $SRC/odoo-ls/server
    git fetch origin $version
    git switch $version --detach
    echo "Compiling Odoo language server version $version in release mode..."
    cargo build --release 2>/dev/null && echo "sucessfully !" || echo "woops, something went wrong :("
    cd $current_dir
}
