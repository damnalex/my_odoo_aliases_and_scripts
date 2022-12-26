# nothing to see here
update_my_beta(){
    local st_branch=$(git -C $ST rev-parse --abbrev-ref HEAD)
    if [[ $st_branch == "my_beta" ]]; then
        git -C $ST fetch;
        git -C $ST rebase origin/master;
        return
    fi
    echo "not curently running 'my_beta' branch, no changes done "
}
