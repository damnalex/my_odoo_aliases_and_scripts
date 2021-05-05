###########################################################
######################  Odoo stuffs #######################
###########################################################

ssho() {
    # connect to odoo servers
    ssh $1.odoo.com -t 'screen -rx'
}

# git stuffs
alias git_odoo="$AP/python_scripts/git_odoo.py"

# pythonable
go_update_and_clean_all_branches() {
    # go through all branches of the universe and mutliverse and pull them
    # It also checks for new modules using the our_module_generator helper
    update_all_multiverse_branches
    local current_working_dir=$(pwd)
    our_modules_update_and_compare
    cd $current_working_dir
    go_prune_all
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
# & is especially important here

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
            local version=$(_db_version $(list_db_like "%$2")) 2>/dev/null
            if [[ $version != "" ]]; then
                go_venv $version
            fi
        fi
    fi
    #start odoo support
    eval $ST/oe-support.py $@
    (clear_pyc &)
}
source $ST/scripts/completion/oe-support-completion.sh
complete -o default -F _oe-support oes

# pythonable
bring_back_masterbeta_to_master() {
    # tool to bring back the master-beta branch of oes
    # to the same "code state" as master, so there is no need
    # to force push to test new things easily
    setopt localoptions rmstarsilent
    local current_working_dir=$(pwd)
    cd $ST
    # create temporary folder and make sure it is clean (maybe the folder already exists)
    mkdir /tmp/tempfolderforoesupportrepo
    rm -rf /tmp/tempfolderforoesupportrepo/*
    # copy everything except the dotfiles, dotfolders, and __pycache__ from the master branche
    git fetch
    git checkout origin/master
    cp -r * /tmp/tempfolderforoesupportrepo
    rm -rf /tmp/tempfolderforoesupportrepo/__pycache__
    # get the curret commit hash to document the new commit
    local master_hash=$(git rev-parse --short HEAD)
    # empty the code of the master-beta branch
    git switch master-beta
    rm -rf *
    # apply the master branch code onto master-beta
    cp -r /tmp/tempfolderforoesupportrepo/* .
    git add .
    git commit -m "[bringing back to master] $master_hash"

    # go back to my starting point
    cd $current_working_dir
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

# pythonable
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
    echo ${version} >>$SRC_MULTI/version_list.txt &&
        sort_and_remove_duplicate $SRC_MULTI/version_list.txt
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
    for version in $(cat $SRC_MULTI/version_list.txt); do {
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
    local version=$1
    local python_inter
    if [[ $# -gt 1 ]]; then
        python_inter="-p$(which $2)"
    else
        # default to python 3
        python_inter="-p$(which python3)"
    fi
    local start_dir=$(pwd)
    cd $SRC_MULTI/$version || return 1
    deactivate || echo "no virtualenv activated"
    if [ -d "o_${version}" ]; then
        echo "virtualenv already exist, rebuilding"
        rm -rf "o_${version}"
    fi
    virtualenv "$python_inter" "o_${version}"
    go_venv $version
    # ignoring in the standard requirements for psycopg2
    sed -i "" "/psycopg2/d" $SRC_MULTI/$version/odoo/requirements.txt
    pip install -r $SRC_MULTI/$version/odoo/requirements.txt
    git -C $SRC_MULTI/$version/odoo stash
    sed -i "" "/psycopg2/d" $ST/requirements.txt
    pip install -r $ST/requirements.txt
    git -C $ST stash
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
    local main_versions=("12.0" "saas-12.3" "13.0" "14.0")
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

# pythonable
build_runbot() {
    # build a runbot like DB
    # TODO: rebuild the runbots and make them immortal
    local version=$1
    local new_db_name=$2
    dropodoo $new_db_name 2>/dev/null
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
    sed -i "" "s|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial'):|if not has_role('trial') and False: #tempcomment|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|assert isnamedtuple(db)|#assert isnamedtuple(db) #tempcomment|" $INTERNAL/default/saas_worker/metabase.py
}

# pythonable
local_saas_config_files_unset() {
    # fix what was done with local_saas_config_files_set
    sed -i "" "s|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|" $INTERNAL/default/saas_worker/const.py
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
            echo "$db_version:    \t $db_name \t($db_size)"
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
    pgbadger -o pgbadger_output.html "$POSTGRES_LOC/postgresql.log" && open pgbadger_output.html
}

pgbadger_clean() {
    # empty the postgresql logs
    echo "" >"$POSTGRES_LOC/postgresql.log"
}

##############################################
###############  tmp aliases #################
##############################################

alias loempia_law="e ~/Documents/meetings_notes/IAmTheLaw/apps_the_rules.txt"
