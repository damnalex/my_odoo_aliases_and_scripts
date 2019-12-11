####################################
#####    completion tools     ######
####################################

_complete_with_B_on_index_A() {
    local index=$1
    local funct=$2
    if [[ COMP_CWORD -eq $((index)) ]]; then
        eval $funct $3 $4 $5 $6 $7 $8 $9
        # this is very ugly, but the completion is doing weird stuff with $@[x,-1]
        # if I need more param, i'll just add more stuff here
        # this also means that a completion command called by _complete_with_B_on_index_A cannot call it back.
    fi
}

####################################
####    completion 'bricks'    #####
####################################

_complete_db_name() {
    local db_name=$(list_db_like "%%" | sed '/CLEAN*/d' | sed '/template*/d' | sed '/meta/d' | sed '/postgres/d' | tr '\n' ' ')
    COMPREPLY=($(compgen -W "$db_name" -- "${COMP_WORD[COMP_CWORD]}"))
}

_complete_db_name_on_first_param() {
    _complete_with_B_on_index_A 1 _complete_db_name
}

_complete_branch_name_on_repo_A() {
    local repo_path=$1
    local branch_names=$(git -C $repo_path branch | tr '\n' ' ')
    COMPREPLY=($(compgen -W "$branch_names" -- "${COMP_WORD[COMP_CWORD]}"))
}

####################################
######     completions     #########
####################################

_eza() {
    if [[ COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "zsh odoo loader drop git typo compl vim tig" -- "${COMP_WORD[1]}"))
    fi
    if [[ COMP_CWORD -eq 2 ]]; then
        local function_names=" "
        case ${COMP_WORDS[1]} in
            zsh)
                function_names=$(grep ".*() {" $AP/zsh_alias.sh | sed 's/() {*//' | tr '\n' ' ')
                ;;
            loader)
                function_names=$(grep ".*() {" $AP/alias_loader.sh | sed 's/() {*//' | tr '\n' ' ')
                ;;
            odoo)
                function_names=$(grep ".*() {" $AP/odoo_alias.sh | sed 's/() {*//' | tr '\n' ' ')
                ;;
            compl)
                function_names=$(grep ".*() {" $AP/completion.sh | grep -v "function_names" | sed 's/() {*//' | tr '\n' ' ')
                ;;
            *) ;;

        esac
        COMPREPLY=($(compgen -W "$function_names" -- "${COMP_WORD[COMP_CWORD]}"))
    fi
}
complete -o default -F _eza eza

_so() {
    _complete_db_name_on_first_param
}
complete -o default -F _so so
complete -o default -F _so soi
complete -o default -F _so sou
complete -o default -F _so goso
complete -o default -F _so ptvsd3-so
complete -o default -F _so ptvsd2-so

complete -o default -F _complete_db_name_on_first_param godb
complete -o default -F _complete_db_name_on_first_param clean_database
complete -o default -F _complete_db_name_on_first_param neuter_db
complete -o default -F _complete_db_name_on_first_param dropodoo
complete -o default -F _complete_db_name_on_first_param lu
complete -o default -F _complete_db_name_on_first_param psql
complete -o default -F _complete_db_name_on_first_param pgcli
complete -o default -F _complete_db_name_on_first_param build_local_saas_db
complete -o default -F _complete_db_name_on_first_param start_local_saas_db

_go() {
    _complete_with_B_on_index_A 1 _complete_branch_name_on_repo_A $ODOO
    _complete_with_B_on_index_A 2 _complete_branch_name_on_repo_A $ENTERPRISE
    _complete_with_B_on_index_A 3 _complete_branch_name_on_repo_A $SRC/design-themes
    _complete_with_B_on_index_A 4 _complete_branch_name_on_repo_A $INTERNAL
}
complete -o default -F _go go

_go_update_and_clean() {
    _complete_with_B_on_index_A 1 _complete_branch_name_on_repo_A $ODOO
}
complete -o default -F _go_update_and_clean go_update_and_clean
