#add odoo to python path
export PYTHONPATH="${PYTHONPATH}:$SRC/odoo"

###########################################################
######################  Odoo stuffs #######################
###########################################################

clear_pyc(){
    find $SRC -name '*.pyc' -delete
}
alias clear_all_pyc="clear_pyc"

#git
go(){ #switch branch for all odoo repos
    local version=$1
    echo "cleaning the junk"
    clear_pyc
    echo "checking out odoo"
    git -C $ODOO checkout $version &&
    if [ $version != "8.0" ]
    then
        echo "checking out enterprise"
        git -C $ENTERPRISE checkout $version &&
    fi
    echo "checking out design-themes"
    git -C $SRC/design-themes checkout $version &&
    ( go_fetch 2> /dev/null & ) # keep this single & here, it's on purpose, also this line needs to be the last one
}

git_update_and_clean(){ # fetch pull and clean a bit a given repo
    local folder=$1
    git -C $folder fetch --all -p  &&
    git -C $folder pull --rebase &&
    git -C $folder prune
}

go_update_and_clean(){
    if [ $# -eq 1 ]
    then
        go $1
    fi
    git_update_and_clean $ODOO &&
    git_update_and_clean $ENTERPRISE &&
    git_update_and_clean $SRC/design-themes &&
    clear_pyc
}

go_fetch(){
    git -C $ODOO fetch origin $(git_branch_version $ODOO) -q
    git -C $ENTERPRISE fetch origin $(git_branch_version $ENTERPRISE) -q
    git -C $SRC/design-themes fetch origin $(git_branch_version $SRC/design-themes) -q
    git -C $INTERNAL fetch origin $(git_branch_version $INTERNAL) -q
    git -C $SRC/support-tools fetch origin $(git_branch_version $SRC/support-tools) -q
}
( go_fetch 2> /dev/null & )
# this is to fetch everytime a terminal is loaded, or sourced, so it happens often 
# & is especially important here

git_branch_version(){
    git -C $1 symbolic-ref --short HEAD
}

git_branch_info(){
    local folder=$1
    local branch_version="$(git_branch_version $folder)"
    local branch_late=$(git -C $folder cherry $branch_version origin/$branch_version 2> /dev/null | wc -l | trim)
    local branch_ahead=$(git -C $folder cherry origin/$branch_version $branch_version 2> /dev/null| wc -l | trim)
    echo "$branch_version \t\t↓ $branch_late ↑ $branch_ahead"
}

golist(){
    echo "current community branch"
    git_branch_info $ODOO
    git -C $ODOO status --short
    echo "\ncurrent enterprise branch"
    git_branch_info $ENTERPRISE
    git -C $ENTERPRISE status --short
    echo "\ncurrent design branch"
    git_branch_info $SRC/design-themes
    git -C $SRC/design-themes status --short
    echo "\ncurrent internal branch"
    git_branch_info $INTERNAL
    git -C $INTERNAL status --short
    echo "\ncurrent support-tools branch"
    git_branch_info $SRC/support-tools
    git -C $SRC/support-tools status --short
    ( go_fetch 2> /dev/null & ) # keep this single & here, it's on purpose, also this line needs to be the last one
}

godb(){
    #switch repos branch to the version of the given DB
    local db_name=$1
    if psql -lqt | cut -d \| -f 1 | grep -qw $db_name; then #check if the database already exists
        go $(_db_version $db_name)
    else
        echo "DB $db_name does not exist"
    fi
}

_db_version(){
    psql -tAqX -d $1 -c "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base';"
}

goso(){
    # switch repos to the versiojn of given db and starts it
    local db_name=$1
    godb $db_name &&
    eval so $db_name $@[2,-1]
}


#start odoo
so(){ 
    _so_checker $@[1,-1] || return 1

    eval $(_so_builder $@[1,-1])
    echo $(_so_builder $@[1,-1])
}

_so_checker(){ 
    local db_name=$1
    if [ $# -lt 1 ]
    then
        echo "At least give me a name :( "
        echo "so dbname [port] [other_parameters]"
        echo "note : port is mandatory if you want to add other parameters"
        return 1
    fi

    if [[ $db_name == CLEAN_ODOO* ]]
    then
        echo "Don't play with that one ! "
        echo "$db_name is a protected database"
        return 1
    fi

    if psql -lqt | cut -d \| -f 1 | grep -qw $db_name; then #check if the database already exists
        if [ $(_db_version $db_name) != $(git_branch_version $ODOO) ]
        then
            echo "version mismatch"
            echo "db version is :"
            _db_version $db_name
            echo "repo version is :"
            git_branch_version $ODOO
            echo "continue anyway ? (Y/n): "
            read answer
            if [ "$answer" = "Y" ]
            then
                echo "I hope you know what you're doing ..."
            else
                echo "Yeah, that's probably safer :D "
                return 1
            fi
        fi
    fi
}

_so_builder(){
    local db_name=$1
    if [ $# -lt 2 ]
    then
        _so_builder $db_name 8069
        return
    fi
    odoo_bin="$ODOO/odoo-bin"
    odoo_py="$ODOO/odoo.py"
    path_community="--addons-path=$ODOO/addons"
    path_enterprise="--addons-path=$ENTERPRISE,$ODOO/addons,$SRC/design-themes"
    params_normal="--db-filter=^$db_name$ -d $db_name --xmlrpc-port=$2"
    if [ -f $ODOO/odoo-bin ]
    then
        #version 10 or above
        echo $ptvsd_T $odoo_bin $path_enterprise $params_normal $@[3,-1]
    else
        #version 9 or below
        if [ $(git_branch_version $ODOO ) = "8.0" ]
        then
            # V8
            echo $ptvsd_T $odoo_py $path_community $params_normal $@[3,-1]
        else
            # V9 (probably)
            echo $ptvsd_T $odoo_py $path_enterprise $params_normal $@[3,-1]
        fi
    fi
}

soiu(){
    local modules_install_arg="-$1 $3"
    for module in $@[4,-1]
    do
        modules_install_arg="${modules_install_arg},$module"
    done
    echo "so $2 1234 $modules_install_arg --stop-after-init"
    eval so $2 1234 $modules_install_arg --stop-after-init
}

soi(){
    echo "installing modules on db $1"
    soiu i $1 $@[2,-1]
}

sou(){
    echo "ugrading modules on db $1"
    soiu u $1 $@[2,-1]
}

oes(){
    #start odoo support
    eval $SRC/support-tools/oe-support.py $@[1,-1]
}
alias eos="oes"

clean_database(){
    eval $SRC/support-tools/clean_database.py $@[1,-1]
}

dropodoo(){
    local db_name_1=$1
    # drop the db, also removes it from meta if it was a local saas db
    if [ $# -lt 1 ]
    then
        echo "requires the name(s) of the DB(s) to drop"
        echo "dropodoo DB_Name [Other_DB_name* ]"
        return 1
    fi
    if [[ $db_name_1 =~ $(echo ^\($(paste -sd'|' $AP/drop_protected_dbs.txt)\)$) ]]; then 
        echo "db $db_name_1 is drop protected --> aborting"
        echo "to override protection, modify protection file at $AP/drop_protected_dbs.txt"
        return 1
    fi
    if [ $# -eq 1 ]
    then
        psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name_1';" -q > /dev/null 
        remove_from_meta $db_name_1 2> /dev/null 
        rm -rf $ODOO_STORAGE/filestore/$db_name_1
        dropdb $db_name_1 || return 1
        echo "$db_name_1 has been dropped"
        return 
    fi
    
    # drop multiple DB at the same time
    for db_name in $@[1,-1]
    do
        dropodoo $db_name
    done
    return
}


droplike(){
    local dbs_list=$(list_db_like $1 | tr '\n' ' ')
    if [ -z $dbs_list ]
    then
        echo "no DB matching the given pattern were found"
    else
        eval dropodoo $dbs_list
    fi
}

build_runbot(){
    # build a runbot like DB
    local version=$1
    local new_db_name=$2
    dropodoo $new_db_name 2> /dev/null
    mkdir $ODOO_STORAGE/filestore/$new_db_name/
    case $version in 
       (9) createdb -T CLEAN_ODOO_V9 $new_db_name 
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V9/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
       (10) createdb -T CLEAN_ODOO_V10 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V10/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
       (11) createdb -T CLEAN_ODOO_V11 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V11/* $ODOO_STORAGE/filestore/$new_db_name/
            psql_seg_fault_fixer $new_db_name
            ;;
       (12) createdb -T CLEAN_ODOO_V12 $new_db_name
            cp -r $ODOO_STORAGE/filestore/CLEAN_ODOO_V12/* $ODOO_STORAGE/filestore/$new_db_name/
            ;;
       (*)  echo "no match for version ${version}" 
            echo "list of valid version:\n9\n10\n11\n12"
            return 1
            ;;
    esac
    echo 'built'
}
alias runbot="build_runbot"

#local-saas

build_local_saas_db(){
    local db_name=$1
    godb $db_name
    if [ -f $ODOO/odoo-bin ]
    then
        eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $db_name -i saas_trial,project --stop-after-init
    else
        eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $db_name -i saas_trial,project --stop-after-init
    fi
    local db_uuid=$(psql -tAqX -d $db_name -c "SELECT value FROM ir_config_parameter WHERE key = 'database.uuid';")
    echo $db_uuid
    echo "INSERT INTO databases (name, uuid, port, mode, extra_apps, create_date, expire_date, last_cnx_date, cron_round, cron_time, email_daily_limit, email_daily_count, email_total_count, print_waiting_counter, print_counter, print_counter_limit) VALUES ('$db_name', '$db_uuid', 8069, 'trial', true, '2018-05-23 09:33:08.811069', '2040-02-22 23:59:59', '2018-06-28 13:44:03.980693', 0, '2018-09-21 00:40:28', 30, 10, 0, 0, 0, 10)" | psql meta
}
alias bloc='build_local_saas_db'

remove_from_meta(){
    echo "DELETE FROM databases WHERE name = '$1'" | psql meta > /dev/null
}

start_local_saas_db(){
    local db_name=$1
    godb $db_name
    local_saas_config_files_set &&
    if [ -f $ODOO/odoo-bin ]
    then
        eval $ptvsd_T $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name --db-filter=^$1$;
    else
        eval $ptvsd_T $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $db_name;
    fi
    local_saas_config_files_unset
}
alias sloc='start_local_saas_db'

local_saas_config_files_set(){
    sed -i "" "s|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|" $INTERNAL/default/saas_worker/const.py
    sed -i "" "s|if not has_role('trial'):|if not has_role('trial') and False: #tempcomment|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|assert isnamedtuple(db)|#assert isnamedtuple(db) #tempcomment|" $INTERNAL/default/saas_worker/metabase.py
}

local_saas_config_files_unset(){
    sed -i "" "s|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|" $INTERNAL/default/saas_worker/const.py   
    sed -i "" "s|if not has_role('trial') and False: #tempcomment|if not has_role('trial'):|" $INTERNAL/default/saas_worker/controllers/support.py
    # this following line only usefull on the mac until I find time to find the cause of the inconsistency
    sed -i "" "s|#assert isnamedtuple(db) #tempcomment|assert isnamedtuple(db)|" $INTERNAL/default/saas_worker/metabase.py
}

list_local_saas(){
    echo "Below, the list of local saas DBs"
    psql -d meta -c "SELECT name, id FROM databases ORDER BY id;" -q
    echo "to start --> start_local_saas_db db-name"
    echo "to create a new one --> build_local_saas_db db-name"
    echo "to drop --> dropodoo db-name"
}
alias lls='list_local_saas'



#start mailcatcher
# this one is only usefull on the odoo linux laptop because I fucked the config up
smailcatcher(){
    echo 'rvm use 2.3 && mailcatcher' | /bin/bash --login
}


ngrok(){
    eval /home/odoo/Documents/programs/ngrok $@[1,-1]
}



#psql aliases
poe(){
    psql oe_support_$1 
}

pl(){
    #echo "select t1.datname as db_name, pg_size_pretty(pg_database_size(t1.datname)) as db_size from pg_database t1 order by t1.datname;" | psql postgres
    local where_clause="where t1.datname not like 'CLEAN_ODOO%' "
    if [ $# -eq 1 ] 
    then
        where_clause="where t1.datname like '%$1%'"
    fi
    local db_name
    for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 $where_clause ORDER BY LOWER(t1.datname);")
    do
        local db_size=$(psql -tAqX -d $db_name -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" 2> /dev/null)
        local db_version=$(_db_version $db_name 2> /dev/null)
        if [ "$db_version" != "" ] #ignore non-odoo DBs
        then
            echo "$db_version:    \t $db_name \t($db_size)"
        fi
    done
}

ploe(){
    # the grep is not necessary, but it makes the base name of the DBs more readable    
    pl oe_support_ | grep oe_support_ 
}

plike(){
    psql $(list_db_like $1) ||
    echo "\n\n\nlooks like there was multiple result for $1, try something more precise"
}

lu(){
    psql -d $1 -c "SELECT id, login FROM res_users where active = true ORDER BY id;" -q
}

luoe(){ 
    lu oe_support_$1 
}

list_db_like(){
    psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 WHERE t1.datname like '$1' ORDER BY LOWER(t1.datname);"
}
alias ldl="list_db_like"


#port killer
listport () {
    lsof -i tcp:$1 
}
killport () {
    listport $1 | sed -n '2p' | awk '{print $2}' |  xargs kill -9 
}



#start python scripts with the vscode python debugger
# note that the debbuger is on the called scrpt, 
# if that script calls another one, that one is not "debugged"
# so it doesn't work with oe-support.
# doesn't work with alias calling python scripts
ptvsd2(){
    eval python2 -m ptvsd --host localhost --port 5678 $@[1,-1] 
}

ptvsd2-so(){
    _so_checker $@[1,-1] || return 1
    eval ptvsd2 $(_so_builder $@[1,-1])
}
alias do2="ptvsd2-so"

ptvsd3(){
    eval python3 -m ptvsd --host localhost --port 5678 $@[1,-1] 
}

ptvsd3-so(){
    _so_checker $@[1,-1] || return 1
    eval ptvsd3 $(_so_builder $@[1,-1])
}
alias do="ptvsd3-so"

export ptvsd_T=" "
ptvsd_toggle(){
    if [ "$1" = "activate" ]; then
        export ptvsd_T="python3 -m ptvsd --host localhost --port 5678"
        echo "ptvsd_T activated"
        return
    elif [ "$1" = "deactivate" ]; then
        export ptvsd_T=" "
        echo "ptvsd_T deactivated"
        return
    elif [ "$ptvsd_T" = " " ]; then
        export ptvsd_T="python3 -m ptvsd --host localhost --port 5678"
        echo "ptvsd_T activated"
        return
    else
        export ptvsd_T=" "
        echo "ptvsd_T deactivated"
        return
    fi
}

ptvsd_odoo(){
    # wrapper alias adding ptvsd import to odoo code
    # executing wrapped command
    # then removing import code from odoo code
    ptvsd_odoo_set &&
    eval $@[1,-1] ; 
    ptvsd_odoo_unset
}

ptvsd_odoo_set(){
    # add ptvsd code to odoo
    # code to add :    import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);
    if [ -f $ODOO/odoo-bin ]
    then
        # v10 and after
        sed -i "" "s|import odoo|import odoo;import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);|" $ODOO/odoo-bin
    else
        # v9 and before
        sed -i "" "s|import os|import os;import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);|" $ODOO/odoo.py
    fi
}

ptvsd_odoo_unset(){
    # remove ptvsd code from odoo
    # code to remove :    import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);
    if [ -f $ODOO/odoo-bin ]
    then
        # v10 and after
        sed -i "" "s|import odoo;import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);|import odoo|" $ODOO/odoo-bin
    else
        # v9 and before
        sed -i "" "s|import os;import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);|import os|" $ODOO/odoo.py
    fi
}

psql_seg_fault_fixer(){
    local db_name=$1
    pg_dump $db_name > $HOME/tmp/tmp.sql && dropdb $db_name && createdb $db_name && psql $db_name -q < $HOME/tmp/tmp.sql && echo "you can restart $db_name now, have fun ! :D"
}

##############################################
###############  tmp aliases #################
##############################################

