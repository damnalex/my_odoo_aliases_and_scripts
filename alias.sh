##############################################
######  "manage this repo"  stuffs  ##########
##############################################

reload_zshrc() {
    # don't modify this one from eza to avoid headaches
    ap_compile
    source ~/.zshrc
    deactivate >/dev/null 2>&1
}

alias e="vim"

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
        # open the folder itself
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
    # change the current directory while editing the files to have a better experience with my vim config
    local current_dir=$(pwd)
    cd $AP
    if [[ $2 == "" ]]; then
        e $AP/$file_to_load || return
    else
        case $file_type in
        sh)
            e -c "/.*$2.*(" $AP/$file_to_load || return
            ;;
        py)
            e -c "/def $2" $AP/$file_to_load || return
            ;;
        other)
            e -c "/$2" $AP/$file_to_load || return
            ;;
        esac
    fi
    cd "$current_dir"
    # editing is done, applying changes
    # source $AP/alias_loader.sh
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
    git -C $repo fetch --prune --all
    git -C $repo branch -vv | grep ': gone] ' | awk '{print $1}' | xargs git -C $repo branch -D
    git -C $repo gc --prune=now
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
    sort_and_remove_duplicate $AP/python_scripts/requirements.txt
    sort_and_remove_duplicate $AP/python_scripts/other_requirements.txt
}

###########################################################
######################  Odoo stuffs #######################
###########################################################

ssho() {
    # connect to odoo servers
    ssh -o "StrictHostKeyChecking no" $1.odoo.com -t 'screen -rx' && return
    echo "---------------------------"
    echo "---------------------------"
    echo "Could not connect to screen"
    echo "---------------------------"
    echo "---------------------------"
    ssh odoo@$1.odoo.com
}

# git stuffs
alias git_odoo="$AP/python_scripts/git_odoo.py"

# pythonable
go_update_and_clean_all_branches() {
    # go through all branches of the universe and mutliverse and pull them
    # It also checks for new modules using the our_module_generator helper
    update_all_multiverse_branches
    go_prune_all
    local current_working_dir=$(pwd)
    our_modules_update_and_compare
    cd $current_working_dir
    clear_pyc --all
    run 5 echo "#############################"
    echo "updated and cleaned all branches of multiverse and universe"
    go_venv_current
}

# pythonable
go_prune_all() {
    # git prune on all the repos of the the universe, multiverse, and on internal and support tools
    # prune universe, internal and paas
    echo "----"
    echo "pruning the universe"
    local repos=("$ODOO" "$ENTERPRISE" "$SRC/design-themes" "$INTERNAL" "$SRC/paas")
    for repo in $repos; do {
        git_prune_branches $repo
    }; done
    # prune multiverse
    echo "----"
    echo "pruning the multiverse"
    repos=("odoo" "enterprise" "design-themes")
    for repo in $repos; do {
        git -C "$SRC_MULTI/master/$repo" worktree prune
        git_prune_branches "$SRC_MULTI/master/$repo"
    }; done
    echo "----"
    echo "All repos have been pruned"
}

golist() {
    # list all the main source folder repos, theire currently checked out branches and theire status
    git_odoo list
    (go_fetch >/dev/null 2>&1 &)
}

(go_fetch >/dev/null 2>&1 &)
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
    (clear_pyc &)
}
source $ST/scripts/completion/oe-support-completion.sh
complete -o default -F _oe-support oes

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

# pythonable
build_multiverse_branch() {
    # create a new mutliverse branche in $SRC_MULTI
    local version=$1
    # building branch
    local repos=("odoo" "enterprise" "design-themes")
    for rep in $repos; do {
        echo ${rep}
        git -C $SRC_MULTI/master/${rep} fetch
        git -C $SRC_MULTI/master/${rep} worktree prune
        git -C $SRC_MULTI/master/${rep} worktree add $SRC_MULTI/${version}/${rep} ${version}
    }; done
}

# pythonable
update_multiverse_branch() {
    # git pull the repos of the given mutliverse branche
    local version=$1
    local repos=("odoo" "enterprise" "design-themes")
    for rep in $repos; do {
        if [[ $version != "8.0" ]] || [[ $rep != "enterprise" ]]; then
            echo ${rep}
            git -C $SRC_MULTI/${version}/${rep} pull --rebase
        fi
    }; done
}

# pythonable
update_all_multiverse_branches() {
    # git pull the repos of all the multivers branches
    echo "###########################################"
    echo "starting to pull multiverse branches"
    echo " -----> master multiverse"
    update_multiverse_branch master
    for version in $(echo $SRC_MULTI/*/ | xargs basename); do {
        if [[ "$version" != "master" ]]; then
            echo " -----> $version multiverse"
            update_multiverse_branch "$version"
        fi
    }; done
    echo "mutliverse branches are up to date"
    echo "###########################################"
}

build_odoo_virtualenv() {
    # (re)create a new virtual env, using the corresponding multiverse branch as a reference
    # stores the virtual env in the multiverse branche, under the o_XXX folder
    deactivate # I don't want virtual envs being based on other virtual envs
    local version=$1
    local python_inter
    if [[ $# -gt 1 ]]; then
        python_inter="-p$(which $2)"
    else
        # default to python 3
        python_inter="-p$(which python3)"
    fi
    local start_dir=$(pwd)
    if [ ! -d "$SRC_MULTI/$version " ]; then
        build_multiverse_branch $version # existance of the multiverse branch is mandatory
    fi
    cd $SRC_MULTI/$version
    if [ -d "o_${version}" ]; then
        echo "virtualenv already exist, rebuilding"
        rm -rf "o_${version}"
    fi
    virtualenv "$python_inter" "o_${version}"
    go_venv $version
    # ignoring in the standard requirements for psycopg2
    cp $SRC_MULTI/$version/odoo/requirements.txt /tmp/requirements.txt
    sed -i "" "/psycopg2/d" /tmp/requirements.txt
    pip install -r /tmp/requirements.txt
    cp $ST/requirements.txt /tmp/requirements.txt
    sed -i "" "/psycopg2/d" /tmp/requirements.txt
    pip install -r /tmp/requirements.txt
    # adding my custom requirements (includes psycopg2-binary)
    pip install -r $AP/python_scripts/requirements.txt
    pip install -r $AP/python_scripts/other_requirements.txt
    cd "$start_dir"
    echo "\n\n\n\n"
    echo "--------------------------------"
    echo "virtualenv o_${version} is ready"
    echo "--------------------------------"
    echo "\n\n\n\n"
}

rebuild_main_virtualenvs() {
    # recreate the main virtual envs
    # usefull when I add something to other_requirements.txt
    local main_versions=("13.0" "14.0" "15.0")
    for version in $main_versions; do {
        build_odoo_virtualenv $version
    }; done
}

go_venv() {
    # use the virtual env of the given odoo version
    deactivate 2>/dev/null
    if [[ $# -eq 1 ]]; then
        local version=$1
        source $SRC_MULTI/$version/o_$version/bin/activate &&
            echo "virtualenv o_$version activated"
    else
        echo "no virtualenv name provided, falling back to standard python env"
    fi
}

go_venv_current() {
    # use the virtualenv for the currently checked out odoo branch
    go_venv $(git_branch_version $ODOO)
}

#local-saas
# pythonable
build_local_saas_db() {
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
            local filestore_size=$(du -sh  $ODOO_STORAGE/filestore/$db_name 2>/dev/null | awk '{print $1}')
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

export POSTGRES_LOC="$HOME/Library/Application Support/Postgres/var-11"
pgbadger_compute() {
    # create the pgbadger result from $POSTGRES_LOC into pgbdager_output.html
    pgbadger -o /tmp/pgbadger_output.html "$POSTGRES_LOC/postgresql.log" && open /tmp/pgbadger_output.html
}

pgbadger_clean() {
    # empty the postgresql logs
    echo "" >"$POSTGRES_LOC/postgresql.log"
}

sync_filestore_to_remote() {
    # sends a local filestore to a remote server in batches (1 per filestore folder)
    # the goal is too use less additional space than a big zip file, while not sending
    # each file individually (which might trigger a network rate limiting)

    args=("$@")
    ELEMENTS=${#args[@]}
    if [ $ELEMENTS -ne 3 ]; then
        echo "Usage: sync_filestore_to_remote    local_filestore_path remote_host remote_filestore_path"
        exit 1
    fi

    local local_filestore_path=$1
    local remote_host=$2
    local remote_filestore_path=$3

    cd $local_filestore_path
    for folder in $(ls); do
        echo "starting work on $folder ------------------------------"
        zip -r "tmp$folder.zip" $folder/*
        echo "finished zipping folder"
        echo "sending °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°"
        rsync -rhP "tmp$folder.zip" "$remote_host:$remote_filestore_path"
        echo "finished sending  °°°°°°°°°°°°°°°°°°°°°°°°°°°°°"
        echo "starting remote commande ##############################"
        ssh $remote_host "cd $remote_filestore_path; unzip -u tmp$folder.zip; rm tmp$folder.zip"
        echo "$folder done ------------------------------------------"
        rm "tmp$folder.zip"
        echo "sleeping 5 seconds to avoid rate limiting on odoosh ..."
        sleep 5
    done
}

# zip archive of what's not present in the other place yet (for odoo filestores)
#   rsync -arvnh . ../filestore2 |  grep \/ | grep -v \/sec | grep -v \/$ | xargs zip -r ../filestorediff.zip
# TODO generalize

# List files that still need to be transfered
#   rsync -arvnh . ../filestore2 |  grep \/ | grep -v \/sec | grep -v \/$
# based on this list function, sync_filestore_to_odoosh could become idempotent AND efficient

# beware of $(getconf ARG_MAX)      (unlikely to cause issue but you never know)

test-dump() {
    # test dump (in the current folder, by default) for safety
    local dump_parent_folder=${2:-$(pwd)}
    local dump_f=$dump_parent_folder/dump.sql
    $PSS/saas/test_dump_safety.py $dump_f || return 1
    # create a DB using the dump.sql file in the current folder
    local db_name="$1-test"
    createdb $db_name || return 1
    psql -d $db_name <$dump_f || return 1
    # neutralize db for local testing
    $ST/lib/neuter.py $db_name --filestore || $ST/lib/neuter.py $db_name
    # start the database just long enough to check if there are custom modules
    godb $db_name
    so $db_name 12345 --stop-after-init
    # show DB version and size
    pl | grep $db_name
}
