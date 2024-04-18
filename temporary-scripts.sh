# nothing to see here
update_my_beta() {
    local st_branch=$(git -C $ST rev-parse --abbrev-ref HEAD)
    if [[ $st_branch == "my_beta" ]]; then
        git -C $ST fetch
        git -C $ST rebase origin/master
        return
    fi
    echo "not curently running 'my_beta' branch, no changes done "
}

minimum_viable_filestore() {
    local db_name=$1
    local original_filestore_path=$2
    local destination_path=${3:-$(pwd)}
    mkdir "$destination_path/filestore"
    for f in $(psql -tAqX -d $db_name -c "select store_fname from ir_attachment where url like '%asset%';"); do
        mkdir $(dirname "$destination_path/filestore/$f") 2>/dev/null
        rsync -r "$original_filestore_path/$f" "$destination_path/filestore/$f"
    done
}

go_update_and_hunter() {
    # git stuff
    go_update_and_clean_all_branches
    cd $SRC/all_standard_odoo_apps_per_version
    [[ $(git log --after="5 minute ago" --oneline) ]] && tig || echo '\n\n\n\n---------  nothing new under the sun -------------\n\n\n\n'
    # apps hunter stuff
    cd $PSS/../apps
    ssh odoo@apps.odoo.com exit
    ./hunter.py
    cd $PSS
}
