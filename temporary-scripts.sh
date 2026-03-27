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
