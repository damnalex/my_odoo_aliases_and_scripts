####################################
#####    completion tools     ######
####################################

_complete_with_B_on_index_A() {
    local index=$1
    local funct=$2
    if [[ COMP_CWORD -eq $(($index)) ]]; then
        eval $funct $@[3, -1]
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

####################################
######     completions     #########
####################################

_eza() {
    if [[ COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "zsh loader drop git start typo compl" -- "${COMP_WORD[1]}"))
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

complete -o default -F _complete_db_name_on_first_param godb
complete -o default -F _complete_db_name_on_first_param clean_database
complete -o default -F _complete_db_name_on_first_param neuter_db
complete -o default -F _complete_db_name_on_first_param dropodoo
complete -o default -F _complete_db_name_on_first_param lu
complete -o default -F _complete_db_name_on_first_param psql
