#add odoo to python path
export PYTHONPATH="${PYTHONPATH}:$SRC/odoo"

###########################################################
######################  Odoo stuffs #######################
###########################################################

clear_pyc() {
    # remove compiled python files from the main source folder
    find $SRC -name '*.pyc' -delete
}

clear_all_pyc() {
    # like clear_pyc, but also cleanes the files in the multiverse folder
    clear_pyc
    find $SRC_MULTI -name '*.pyc' -delete
}

# git stuffs
alias git_odoo="$AP/python_scripts/git_odoo.py"
go() {
    #switch branch for all odoo repos
    echo "cleaning the junk"
    clear_pyc
    if [[ $# -gt 1 ]]; then
        _go_multi $@
    else
        local version=$1
        git_odoo checkout $version
        go_venv $version
    fi
    echo "-------"
    golist
}

_go_multi() {
    #switch to specific branch/commit for each repo seperatly
    if [[ $# -ge 2 ]]; then
        echo "checkouting community repo to $1"
        git -C $ODOO checkout $1
        echo "checkouting enterprise repo to $2"
        git -C $ENTERPRISE checkout $2
    fi
    if [[ $# -ge 3 ]]; then
        echo "checkouting design-themes repo to $3"
        git -C $SRC/design-themes checkout $3
    fi
    if [[ $# -eq 4 ]]; then
        echo "checkouting internal repo to $4"
        git -C $INTERNAL checkout $4
    fi
    if [[ $# -gt 4 ]]; then
        echo "too many params, ignoring the following:"
        echo "$@[5, -1]"
        return 1
    fi
}

go_update_and_clean() {
    # git pull on all the repos of the main source folder
    if [ $# -eq 1 ]; then
        git_odoo pull --version $1
        go_venv $1
    else
        git_odoo pull
    fi
    git -C $INTERNAL pull --rebase
    clear_pyc
    echo "-------"
    golist
}

go_update_and_clean_all_branches() {
    #like go_update_and_clean, but does the multiverse, and internal too
    # parallelize git operations on different repos
    git -C $INTERNAL pull --rebase &
    local inter_pid=$!
    update_all_multiverse_branches &
    local multiv_pid=$!
    git_odoo pull --all &
    local univers_pid=$!
    wait_for_pid $inter_pid
    wait_for_pid $multiv_pid
    wait_for_pid $univers_pid
    echo "all branches have been pulled"
    go_prune_all
    clear_all_pyc
    run 5 echo "#############################"
    echo "updated and cleaned all branches of multiverse and universe"
    go_venv_current
}

go_fetch() {
    #git fetch on all the repos of the main source folder
    git_odoo fetch
}
(go_fetch > /dev/null 2>&1 &)
# this is to fetch everytime a terminal is loaded, or sourced, so it happens often
# & is especially important here

go_prune_all() {
    # git prune on all the repos of the the universe, multiverse, and on internal and support tools
    local pid_array=()
    # prune universe
    local repos=("$ODOO" "$ENTERPRISE" "$SRC/design-themes" "$INTERNAL" "$ST")
    for repo in $repos; do {
        git -C "$repo" gc --prune=now &
        pid_array=("${pid_array[@]}" "$!")
    }; done
    # prune multiverse
    repos=("odoo" "enterprise" "design-themes")
    for repo in $repos; do {
        git -C "$SRC_MULTI/master/$repo" worktree prune &
        pid_array=("${pid_array[@]}" "$!")
    }; done
    # wait for all background pruning to finish
    for pidn in $pid_array; do {
        wait_for_pid "$pidn"
    }; done
    echo "----"
    echo "All repos have been pruned"
}

git_branch_version() {
    # get the name of the branch of a given repo
    git -C $1 symbolic-ref --short HEAD
}

golist() {
    # list all the main source folder repos, theire currently checked out branches and theire status
    git_odoo list
    (go_fetch > /dev/null 2>&1 &)
}

godb() {
    # switch repos branch to the version of the given DB
    local db_name=$1
    if psql -lqt | cut -d \| -f 1 | grep -qw $db_name; then #check if the database already exists
        git_odoo checkout --dbname $db_name
        go_venv $(_db_version $db_name)
    else
        echo "DB $db_name does not exist"
    fi
}

_db_version() {
    # get the version on an odoo DB 
    psql -tAqX -d $1 -c "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base';"
}

goso() {
    # switch repos to the version of given db and starts it
    local db_name=$1
    godb $db_name &&
        eval so $@
}

so() {
    # start odoo
    if [[ $1 == "--help" ]]; then
        so fakeDBname 678 --help | less
        # fakeDBname & 678 don't mean anything here
        return 0
    fi
    _so_checker $@ || return 1
    eval $(_so_builder $@)
    echo $(_so_builder $@)
}

_so_checker() {
    # check that the params given to 'so' are correct,
    # check that I am not trying to start a protected DB,
    # check that I am sure to want to start a DB with the wrong branch checked out (only check $ODOO)
    local db_name=$1
    if [ $# -lt 1 ]; then
        echo "At least give me a name :( "
        echo "so dbname [port] [other_parameters]"
        echo "note : port is mandatory if you want to add other parameters"
        return 1
    fi

    if [[ $db_name == CLEAN_ODOO* ]]; then
        echo "Don't play with that one ! "
        echo "$db_name is a protected database"
        return 1
    fi

    if psql -lqt | cut -d \| -f 1 | grep -qw $db_name; then #check if the database already exists
        if [ $(_db_version $db_name) != $(git_branch_version $ODOO) ]; then
            echo "version mismatch"
            echo "db version is :"
            _db_version $db_name
            echo "repo version is :"
            git_branch_version $ODOO
            echo "continue anyway ? (y/N): "
            read answer
            if [ "$answer" = "y" ]; then
                echo "I hope you know what you're doing ..."
            else
                echo "Yeah, that's probably safer :D "
                return 1
            fi
        fi
    fi
}

_so_builder() {
    # build the command to start odoo
    local db_name=$1
    if [ $# -lt 2 ]; then
        _so_builder $db_name 8069
        return
    fi
    odoo_bin="$ODOO/odoo-bin"
    odoo_py="$ODOO/odoo.py"
    path_community="--addons-path=$ODOO/addons"
    path_enterprise="--addons-path=$ENTERPRISE,$ODOO/addons,$SRC/design-themes"
    params_normal="--db-filter=^$db_name$ -d $db_name --xmlrpc-port=$2"
    if [ -f $ODOO/odoo-bin ]; then
        #version 10 or above
        echo $odoo_bin $path_enterprise $params_normal $@[3,-1]
    else
        #version 9 or below
        if [ $(git_branch_version $ODOO) = "8.0" ]; then
            # V8
            echo $odoo_py $path_community $params_normal $@[3,-1]
        else
            # V9 (probably)
            echo $odoo_py $path_enterprise $params_normal $@[3,-1]
        fi
    fi
}

soiu() {
    # update ($1 == u) or install ($1 == i) modules $4-... on DB $2
    local modules_install_arg="-$1 $3"
    for module in $@[4,-1]; do
        modules_install_arg="${modules_install_arg},$module"
    done
    echo "so $2 1234 $modules_install_arg --stop-after-init"
    eval so $2 1234 $modules_install_arg --stop-after-init
}

soi() {
    # install modules $3-... on DB $1
    echo "installing modules on db $1"
    soiu i $1 $@[2,-1]
}

sou() {
    # update modules $3-... on DB $1
    echo "ugrading modules on db $1"
    soiu u $1 $@[2,-1]
}

oes() {
    # start oe-support, with some smartness
    if [[ $1 == "fetch" ]] && ! [[ $* == *'--no-start'* ]]; then
        # running first a fetch without starting the db
        # then running a separate start to automagically
        # use the right virtual-env, even when the db version
        # is not known beforehand
        eval oes $@ --no-start
        eval oes start $@[2,-1]
        return
    fi
    if [[ $1 == "start" ]] || [[ $1 == "restore" ]]; then
        local version=$(_db_version $(list_db_like "%$2")) 2> /dev/null
        if [[ $version != "" ]]; then
            go_venv $version
        fi
    fi
    #start odoo support
    eval $ST/oe-support.py $@
    (clear_pyc &)
}
source $ST/scripts/completion/oe-support-completion.sh
complete -o default -F _oe-support oes

clean_database() {
    # start clean_database.py, dumbly
    eval $ST/clean_database.py $@
}

neuter_db() {
    # neutre a DB without using oe-support
    local db_name=$1
    psql $db_name < $AP/support_scripts/neuter_db.sql
}

odoosh_ssh() {
    # start odoosh.py, dumbly
    local url=$1
    eval $ST/odoosh/odoosh.py $url
}

alias psql_odoo="$AP/python_scripts/psql_odoo.py"

dropodoo() {
    # drop the given DBs and remove its filestore, also removes it from meta if it was a local saas db
    local db_name_1=$1
    if [ $# -lt 1 ]; then
        echo "requires the name(s) of the DB(s) to drop"
        echo "dropodoo DB_Name [Other_DB_name* ...]"
        return 1
    fi
    if [[ $db_name_1 =~ $(echo ^\($(paste -sd'|' $AP/drop_protected_dbs.txt)\)$) ]]; then
        echo "db $db_name_1 is drop protected --> aborting"
        echo "to override protection, modify protection file at $AP/drop_protected_dbs.txt"
        return 1
    fi
    if [[ $db_name_1 =~ '^oe_support_*' ]]; then
        echo "Dropping the DB ${db_name_1} using oe-support"
        oes cleanup ${db_name_1:11}
        return 1
    fi
    if [ $# -eq 1 ]; then
        psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name_1';" -q > /dev/null
        remove_from_meta $db_name_1 2> /dev/null
        rm -rf $ODOO_STORAGE/filestore/$db_name_1
        dropdb $db_name_1 || return 1
        echo "$db_name_1 has been dropped"
        return 1
    fi

    # drop multiple DB at the same time
    for db_name in $@; do
        dropodoo $db_name
    done
    return
}

droplike() {
    # drop the DBs with the given patern (sql style patern)
    local dbs_list=$(list_db_like $1 | tr '\n' ' ')
    if [ -z $dbs_list ]; then
        echo "no DB matching the given pattern were found"
    else
        eval dropodoo $dbs_list
    fi
}

build_multiverse_branch() {
    # create a new mutliverse branche in $SRC_MULTI
    local version=$1
    # building branch
    local repos=("odoo" "enterprise" "design-themes")
    for rep in $repos; do {
        echo ${rep}
        git -C $SRC_MULTI/master/${rep} worktree prune
        git -C $SRC_MULTI/master/${rep} worktree add $SRC_MULTI/${version}/${rep} ${version}
    }; done
    # adding branch to list of known branches
    echo ${version} >> $SRC_MULTI/version_list.txt &&
        sort_and_remove_duplicate $SRC_MULTI/version_list.txt
}

update_multiverse_branch() {
    # git pull the repos of the given mutliverse branche
    local version=$1
    local repos=("odoo" "enterprise" "design-themes")
    local pid_array=()
    for rep in $repos; do {
        if [[ $version != "8.0" ]] || [[ $rep != "enterprise" ]]; then
            echo ${rep}
            git -C $SRC_MULTI/${version}/${rep} pull --rebase &
            pid_array=("${pid_array[@]}" "$!")
        fi
    }; done
    for pidn in $pid_array; do {
        wait_for_pid "$pidn"
    }; done
}

update_all_multiverse_branches() {
    # git pull the repos of all the multivers branches
    local pid_array=()
    for version in $(cat $SRC_MULTI/version_list.txt); do {
        echo $version
        # execute update of individual branches in the background
        update_multiverse_branch "$version" > /dev/null &
        # record all background tasks
        pid_array=("${pid_array[@]}" "$!")
    }; done
    # wait for all background tasks to finish
    for pidn in $pid_array; do {
        wait_for_pid "$pidn"
    }; done
    echo "###########################################"
    echo "mutliverse branches are up to date"
}

build_odoo_virtualenv() {
    # (re)create a new virtual env, using the corresponding multiverse branch as a reference
    # stores the virtual env in the multiverse branche, under the o_XXX folder
    local version=$1
    local python_inter
    if [[ $# -gt 1 ]]; then
        python_inter=$2
    else
        python_inter="python3"
    fi
    local start_dir=$(pwd)
    cd $SRC_MULTI/$version || return 1
    deactivate || echo "no virtualenv activated"
    if [ -d "o_${version}" ]; then
        echo "virtualenv already exist, rebuilding"
        rm -rf "o_${version}"
    fi
    virtualenv -p $(which $python_inter) "o_${version}" &&
        go_venv $version &&
        pip install -r $SRC_MULTI/$version/odoo/requirements.txt
    pip install -r $ST/requirements.txt
    pip install -r $AP/python_scripts/requirements.txt
    pip install -r $AP/python_scripts/other_requirements.txt
    cd "$start_dir"
    echo "\n\n\n\n"
    echo "virtualenv o_${version} is ready"
}

rebuild_main_virtualenvs() {
    # recreate the main virtual envs
    # usefull when I add something to other_requirements.txt
    local main_versions=("11.0" "12.0" "13.0")
    for version in $main_versions; do {
        build_odoo_virtualenv $version
    }; done
}

go_venv() {
    # use the virtual env of the given odoo version
    deactivate 2> /dev/null
    if [[ $# -eq 1 ]]; then
        local version=$1
        source $SRC_MULTI/$version/o_$version/bin/activate &&
            echo "virtualenv o_$version activated"
    else
        echo "no virtualenv name provided, falling back to standard python env"
    fi
}
alias gov="go_venv"

go_venv_current() {
    # use the virtualenv for the currently checked out odoo branch
    gov $(git_branch_version $ODOO)
}
alias govcur="go_venv_current"
govcur # use the right virtual env on terminal startup and reload

build_runbot() {
    # build a runbot like DB
    # TODO: rebuild the runbots and make them immortal
    local version=$1
    local new_db_name=$2
    dropodoo $new_db_name 2> /dev/null
    mkdir $ODOO_STORAGE/filestore/$new_db_name/
    case $version in
        8)
            createdb -T CLEAN_ODOO_V8 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V8/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
        9)
            createdb -T CLEAN_ODOO_V9 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V9/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
        10)
            createdb -T CLEAN_ODOO_V10 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V10/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
        11)
            createdb -T CLEAN_ODOO_V11 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V11/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
        12)
            createdb -T CLEAN_ODOO_V12 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V12/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
        *)
            echo "no match for version ${version}"
            echo "list of valid version:\n9\n10\n11\n12"
            return 1
            ;;
    esac
    echo 'built'
}
alias runbot="build_runbot"

#local-saas

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
alias bloc='build_local_saas_db'

remove_from_meta() {
    # remove a db from the local metabase
    echo "DELETE FROM databases WHERE name = '$1'" | psql meta > /dev/null
}

start_local_saas_db() {
    # start a local db as if it was on the saas, need to run build_local_saas_db first
    local db_name=$1
    godb $db_name
    local_saas_config_files_set &&
        if [ -f $ODOO/odoo-bin ]; then
            eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name --db-filter=^$1$ $@[2,-1]
        else
            eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name $@[2,-1]
        fi
    local_saas_config_files_unset
}
alias sloc='start_local_saas_db'

local_saas_config_files_set() {
    # modify the source code of internal to allow me to run db with start_local_saas_db
    sed -i "" "s|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial'):|if not has_role('trial') and False: #tempcomment|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|assert isnamedtuple(db)|#assert isnamedtuple(db) #tempcomment|" $INTERNAL/default/saas_worker/metabase.py
}

local_saas_config_files_unset() {
    # fix what was done with local_saas_config_files_set
    sed -i "" "s|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial') and False: #tempcomment|if not has_role('trial'):|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|#assert isnamedtuple(db) #tempcomment|assert isnamedtuple(db)|" $INTERNAL/default/saas_worker/metabase.py
}

list_local_saas() {
    # list the DB that were SAASifyied
    echo "Below, the list of local saas DBs"
    psql -d meta -c "SELECT name, id FROM databases ORDER BY id;" -q
    echo "to start --> start_local_saas_db db-name"
    echo "to create a new one --> build_local_saas_db db-name"
    echo "to drop --> dropodoo db-name"
}
alias lls='list_local_saas'

#psql aliases
pl() {
    # list odoo DBs
    #echo "select t1.datname as db_name, pg_size_pretty(pg_database_size(t1.datname)) as db_size from pg_database t1 order by t1.datname;" | psql postgres
    local where_clause="where t1.datname not like 'CLEAN_ODOO%' "
    if [ $# -eq 1 ]; then
        where_clause="where t1.datname like '%$1%'"
    fi
    for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 $where_clause ORDER BY LOWER(t1.datname);"); do
        local db_version=$(_db_version $db_name 2> /dev/null)
        if [ "$db_version" != "" ]; then #ignore non-odoo DBs
            local db_size=$(psql -tAqX -d $db_name -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" 2> /dev/null)
            echo "$db_version:    \t $db_name \t($db_size)"
        fi
    done
}

ploe() {
    # like pl, but just for the oe_support_XXX DBs
    # the grep is not necessary, but it makes the base name of the DBs more readable
    pl oe_support_ | grep oe_support_
}

plike() {
    # psql $1 but with an incomplete name, in a sql like style (useless since the autocompletion of psql, I think)
    psql $(list_db_like $1) ||
        echo "\n\n\nlooks like there was multiple result for $1, try something more precise"
}

lu() {
    # list the users of DB $1 and copy the username of the admin in the clipboard
    psql -d $1 -c "SELECT login FROM res_users where active = true ORDER BY id LIMIT 1;" -tAqX | pbcopy
    psql -d $1 -c "SELECT id, login FROM res_users where active = true ORDER BY id;" -q
}

list_db_like() {
    # list the DBs with a name that match the pattern (sql like style)
    psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 WHERE t1.datname like '$1' ORDER BY LOWER(t1.datname);"
}
alias ldl="list_db_like"

db_age() {
    # tels the age of a given DB
    local db_name=$1
    local query="SELECT datname, (pg_stat_file('base/'||oid ||'/PG_VERSION')).modification FROM pg_database WHERE datname LIKE '$db_name'"
    psql -c "$query" -d postgres
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

#start python scripts with the vscode python debugger
# note that the debbuger is on the called script,
# if that script calls another one, that one is not "debugged"
# so it doesn't work with oe-support.
# doesn't work with alias calling python scripts
ptvsd2() {
    eval python2 -m ptvsd --host localhost --port 5678 $@
}

ptvsd2-so() {
    _so_checker $@ || return 1
    if [ $# -lt 2 ]; then
        echo "The port number is a mandatory parameter"
        return 1
    fi
    eval ptvsd2 $(_so_builder $@ --limit-time-real=1000 --limit-time-cpu=600)
}
alias debo2="ptvsd2-so"

ptvsd3() {
    eval python3 -m ptvsd --host localhost --port 5678 $@
}

ptvsd3-so() {
    _so_checker $@ || return 1
    if [ $# -lt 2 ]; then
        echo "The port number is a mandatory parameter"
        return 1
    fi
    eval ptvsd3 $(_so_builder $@ --limit-time-real=1000 --limit-time-cpu=600)
}
alias debo="ptvsd3-so"

export POSTGRES_LOC="$HOME/Library/Application Support/Postgres/var-11"
pgbadger_compute() {
    # create the pgbadger result from $POSTGRES_LOC into pgbdager_output.html
    pgbadger -o pgbadger_output.html "$POSTGRES_LOC/postgresql.log" && open pgbadger_output.html
}

pgbadger_clean() {
    # empty the postgresql logs
    echo "" > "$POSTGRES_LOC/postgresql.log"
}

##############################################
###############  tmp aliases #################
##############################################

alias todayilearned="e ~/Documents/meetings_notes/today_I_leanred_backlog.txt"
alias thingsToChangeInOESupport="e ~/Documents/things_to_change_in_oe-support.txt"
alias loempia_law="e ~/Documents/meetings_notes/IAmTheLaw/apps_the_rules.txt"

