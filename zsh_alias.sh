###########################################################
########################  PATHS  ##########################
###########################################################

export SRC="/home/odoo/src"
export ODOO="$SRC/odoo"
export ENTERPRISE="$SRC/enterprise"
export INTERNAL="$SRC/internal"
export AP="/home/odoo/Documents/my_scripts/aliases_and_script_repo" #alias path

###########################################################
############  things to make my system work  ##############
###########################################################

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

#add odoo to python path
export PYTHONPATH="${PYTHONPATH}:$SRC/odoo"

DEFAULT_USER='odoo'

###########################################################
##########  things to make zsh aliases work  ##############
###########################################################

alias e="vim"

eza(){
	e $AP/zsh_alias.sh && 
	reload_zshrc
}

geza(){
	gedit $AP/zsh_alias.sh &&
	reload_zshrc
}

###########################################################
######################  Odoo stuffs #######################
###########################################################

clear_pyc(){
	find $SRC -name '*.pyc' -delete
}
alias clear_all_pyc="clear_pyc"

#git
go(){ #switch branch for all odoo repos
	echo "cleaning the junk"
	clear_pyc
	echo "checking out odoo"
	git -C $ODOO checkout $1 &&
	if [ $1 != "8.0" ]
	then
		echo "checking out enterprise"
		git -C $ENTERPRISE checkout $1 &&
	fi
	echo "checking out design-themes"
	git -C $SRC/design-themes checkout $1 
}

git_update_and_clean(){ # fetch pull and clean a bit a given repo
	git -C $1 fetch --all &&
	git -C $1 pull --rebase &&
	git -C $1 prune
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

git_branch_version(){
	git -C $1 symbolic-ref --short HEAD
}

golist(){
	echo "current community branch"
	git_branch_version $ODOO
	echo "current enterprise branch"
	git_branch_version $ENTERPRISE
	echo "current design branch"
	git_branch_version $SRC/design-themes
	echo "current internal branch"
	git_branch_version $INTERNAL
	echo "current support-tools branch"
	git_branch_version $SRC/support-tools
}

godb(){
	#switch repos branch to the version of the given DB
	if psql -lqt | cut -d \| -f 1 | grep -qw $1; then #check if the database already exists
		go $(so-version $1)
	else
		echo "DB $1 does not exist"
	fi
}

goso(){
	# switch repos to the versiojn of given db and starts it
	godb $1 &&
	so $1
}


#start odoo
so(){ 
	#params  -->   dbname [port] [other_parameters]
	if psql -lqt | cut -d \| -f 1 | grep -qw $1; then #check if the database already exists
		if [ $(so-version $1) != $(git_branch_version $ODOO) ]
		then
			echo "version mismatch"
			echo "db version is :"
			so-version $1
			echo "repo version is :"
			git_branch_version $ODOO
			return
		fi
	fi

	if [ $# -lt 1 ]
	then
		echo "At least give me a name :( "
		echo "so dbname [port] [other_parameters]"
		echo "note : port is mandatory if you want to add other parameters"
		return
	fi
	if [ $# -lt 2 ]
	then
		so $1 8069
		return
	fi

	odoo_bin="$ODOO/odoo-bin"
	odoo_py="$ODOO/odoo.py"
	path_community="--addons-path=$ODOO/addons"
	path_enterprise="--addons-path=$ENTERPRISE,$ODOO/addons,$SRC/design-themes"
	params_normal="--db-filter=^$1$ -d $1 --xmlrpc-port=$2"
	params_silent="--db-filter=^$1$ -d $1 --xmlrpc-port=$2 --log-level=warn --log-handler=werkzeug:CRITICAL"
	if [ -f $ODOO/odoo-bin ]
	then
		#version 10 or above
		if [ "$3" != "silent" ]
		then
			eval $ptvsd_T $odoo_bin $path_enterprise $params_normal $@[3,-1]
		else
			eval $ptvsd_T $odoo_bin $path_enterprise $params_silent $@[4,-1]
		fi
	else
		#version 9 or below
		if [ $(git_branch_version $ODOO ) = "8.0" ]
		then
		    # V8
		    if [ "$3" != "silent" ]
		    then
				eval $ptvsd_T $odoo_py $path_community $params_normal $@[3,-1]
		    else
				eval $ptvsd_T $odoo_py $path_community $params_silent $@[4,-1]
		    fi
		else
		    # V9 (probably)
		    if [ "$3" != "silent" ]
		    then
				eval $ptvsd_T $odoo_py $path_enterprise $params_normal $@[3,-1]
		    else
				eval $ptvsd_T $odoo_py $path_enterprise $params_silent $@[4,-1]
		    fi
		fi
	fi
}

so-version(){
	psql -tAqX -d $1 -c "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base';"
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

dropodoo(){
	# drop the db, also removes it from meta if it was a local saas db
	if [ $# -lt 1 ]
	then
		echo "requires the name(s) of the DB(s) to drop"
		echo "dropodoo DB_Name [Other_DB_name* ]"
		return
	fi
	if [ $# -eq 1 ]
	then
		psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$1';" -q > /dev/null 
		drop_local_saas_db $1 2> /dev/null || echo "failed to delete db $1, maybe it doesn't exist ?"
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



#local-saas

build_local_saas_db(){
	godb $1
	if [ -f $ODOO/odoo-bin ]
	then
		eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $1 -i saas_trial,project --stop-after-init
	else
		eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d $1 -i saas_trial,project --stop-after-init
	fi
	local db_uuid=$(psql -tAqX -d $1 -c "SELECT value FROM ir_config_parameter WHERE key = 'database.uuid';")
	echo $db_uuid
	echo "INSERT INTO databases (name, uuid, port, mode, extra_apps, create_date, expire_date, last_cnx_date, cron_round, cron_time, email_daily_limit, email_daily_count, email_total_count, print_waiting_counter, print_counter, print_counter_limit) VALUES ('$1', '$db_uuid', 8069, 'trial', true, '2018-05-23 09:33:08.811069', '2040-02-22 23:59:59', '2018-06-28 13:44:03.980693', 0, '2018-09-21 00:40:28', 30, 10, 0, 0, 0, 10)" | psql meta
}
alias bloc='build_local_saas_db'

drop_local_saas_db(){
	echo "DELETE FROM databases WHERE name = '$1'" | psql meta > /dev/null
	dropdb $1 && echo "database $1 has been dropped"
}

start_local_saas_db(){
	godb $1
	local_saas_config_files_set &&
	if [ -f $ODOO/odoo-bin ]
	then
		eval $ptvsd_T $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $1 --db-filter=^$1$;
	else
		eval $ptvsd_T $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons,$SRC/design-themes --load=saas_worker,web -d $1;
	fi
	local_saas_config_files_unset
}
alias sloc='start_local_saas_db'

local_saas_config_files_set(){
	sed -i "s|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|" $INTERNAL/default/saas_worker/const.py
}

local_saas_config_files_unset(){
	sed -i "s|OAUTH_BASE_URL = 'https://accounts.odoo.com' #tempcomment|OAUTH_BASE_URL = 'http://accounts.127.0.0.1.xip.io:8369'|" $INTERNAL/default/saas_worker/const.py	
}

list_local_saas(){
	echo "Below, the list of local saas DBs"
	psql -d meta -c "SELECT name, id FROM databases ORDER BY id;" -q
	echo "to start --> start_local_saas_db db-name"
	echo "to create a new one --> build_local_saas_db db-name"
	echo "to drop --> drop_local_saas_db db-name"
}
alias lls='list_local_saas'

SaaS_Inj_git10_and_start(){
	clear
	go 10.0 &&
	local_saas_config_files_set &&
	eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web --db-filter=SAAS_TEST_Sess_Inject_V10 ;
	local_saas_config_files_unset
}

SaaS_Inj_git11_and_start(){
	clear 
	go 11.0 &&
	local_saas_config_files_set &&
	eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d SAAS_TEST_Sess_Inject ;
	local_saas_config_files_unset
}

SaaS_Inj_git9tbe_and_start(){
	clear
	clear_pyc &&
	git -C $ODOO checkout 9.0-session-token-tbe && 
	git -C $ENTERPRISE checkout 9.0 && 
	local_saas_config_files_set &&
	eval $ODOO/odoo.py --addons-path=$INTERNAL/default,$INTERNAL/trial,$ENTERPRISE,$ODOO/addons --load=saas_worker,web --db-filter=SAAS_TEST_Sess_Inject_V9tbe ;
	local_saas_config_files_unset
}

SaaS_Inj_git8patched_and_start(){
	clear 
	clear_all_pyc && 
	git -C $ODOO checkout 8.0-local_patch_for_local_saas && 
	local_saas_config_files_set &&
	eval $ODOO/odoo.py -d SAAS_V8 --db-filter=^SAAS_V8$ --addons-path=$ODOO/addons,$INTERNAL/default/,$INTERNAL/trial/ --load=saas_worker,web ;
	local_saas_config_files_unset
}






#helpdesk-mig
helpdesk114_drop_build_start_db(){
	dropdb helpdesk114 && 
	createdb helpdesk114 && 
	psql helpdesk114 < /home/odoo/Documents/mig/helpdesk114.dump.sql && 
	cd ~/src/odoo && 
	git checkout saas-11.4 && 
	cd ~/src/enterprise && 
	git checkout saas-11.4 && 
	cd && 
	/home/odoo/src/odoo/odoo-bin --addons-path=/home/odoo/src/internal/default,/home/odoo/src/internal/private,/home/odoo/src/internal/test,/home/odoo/src/enterprise,/home/odoo/src/odoo/addons --load=saas_worker,web -d helpdesk114
}

helpdesk114_just_start(){
	go saas-11.4 &&
	eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/private,$INTERNAL/test,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d helpdesk114
}

helpdesk114_migrate(){
	date +%s.%N
	# psql helpdesk114 < /home/odoo/Documents/mig/whe-migration_script_more_readable.sql
	psql helpdesk114 < /home/odoo/Documents/mig/migration/Migration_from_project.task_to_helpdesk.ticket.sql
	date +%s.%N
}

helpdesk114_update_dump(){
	pg_dump helpdesk114 > /home/odoo/Documents/mig/helpdesk114.dump.sql
}


# not ready yet (enterprise repo needs to be update to be ready for v12)
helpdesk12_drop_build_start_db(){
	dropdb helpdesk12 &&
	createdb helpdesk12 &&
	psql helpdesk12 < /home/odoo/Documents/mig/helpdesk12.dump.sql &&
	go 12.0 &&
	eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/private,$INTERNAL/test,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d helpdesk12
}

helpdesk12_just_start_db(){
	go 12.0 &&
	eval $ODOO/odoo-bin --addons-path=$INTERNAL/default,$INTERNAL/private,$INTERNAL/test,$ENTERPRISE,$ODOO/addons --load=saas_worker,web -d helpdesk12
}

helpdesk12_migrate(){
	date +%s.%N
	psql helpdesk12 < /home/odoo/Documents/mig/migration/Migration_from_project.task_to_helpdesk.ticket.sql
	date +%s.%N
}

helpdesk12_update_dump(){
	pg_dump helpdesk12 > /home/odoo/Documents/mig/helpdesk12.dump.sql
}






#start mailcatcher
smailcatcher(){
	echo 'rvm use 2.3 && mailcatcher' | /bin/bash --login
}





#psql aliases
poe(){
	psql oe_support_$1 
}

pl(){
	#echo "select t1.datname as db_name, pg_size_pretty(pg_database_size(t1.datname)) as db_size from pg_database t1 order by t1.datname;" | psql postgres
	local where_clause=" "
	if [ $# -eq 1 ] 
	then
		where_clause="where t1.datname like '%$1%'"
	fi
	local db_name
	for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 $where_clause ORDER BY LOWER(t1.datname);")
	do
		local db_size=$(psql -tAqX -d $db_name -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" 2> /dev/null)
		local db_version=$(so-version $db_name 2> /dev/null)
		if ! [ -z $db_version ]
		then
			echo "$db_version:    \t $db_name \t($db_size)"
		fi
	done
}

ploe(){
	# the grep is not necessary, but it makes the base name of the DBs more readable	
	pl oe_support_ | grep oe_support_ 
}

lu(){
	psql -d $1 -c "SELECT id, login FROM res_users ORDER BY id;" -q
}

luoe(){	
	lu oe_support_$1 
}

list_db_like(){
	psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 WHERE t1.datname like '$1' ORDER BY LOWER(t1.datname);"
}



#port killer
listport () {
	lsof -i tcp:$1 
}
killport () {
	listport $1 | sed -n '2p' | awk '{print $2}' |  xargs kill -9 
}


#history analytics
history_count(){
	history -n | cut -d' ' -f1 | sort | uniq -c | trim | sort -g | tac | less
}
trim(){
	awk '{$1=$1};1'
}




#start python scripts with the vscode python debugger
ptvsd(){
	eval python -m ptvsd --host localhost --port 5678 $@[1,-1] 
}

export ptvsd_T=" "
ptvsd_toggle(){
	if [ $ptvsd_T = " " ]; then
		export ptvsd_T="python -m ptvsd --host localhost --port 5678"
		echo "ptvsd_T activated"
	else
		export ptvsd_T=" "
		echo "ptvsd_T deactivated"
	fi
}

# ptvsd_odoo_set(){
# 	# add ptvsd code to odoo
# 	# code to add :    import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);
# }
# 
# ptvsd_odoo_unset(){
# 	# remove ptvsd code from odoo
# 	# code to remove :    import ptvsd; ptvsd.enable_attach(address=('localhost', 5678), redirect_output=True);
# }

##############################################
#############""  tmp aliases
#############################################


