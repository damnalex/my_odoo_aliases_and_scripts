####################################
####    completion helpers     #####
####################################

_complete_db_name(){
    local db_name=$(list_db_like "%%" | sed '/CLEAN*/d' | sed '/template*/d' | sed '/meta/d' |sed '/postgres/d' | tr '\n' ' ')
    COMPREPLY=($(compgen -W "$db_name" -- "${COMP_WORD[COMP_CWORD]}"))
}

####################################
######     completions     #########
####################################

_eza(){
    if [[ COMP_CWORD -eq 1 ]]
    then
        COMPREPLY=($(compgen -W "zsh loader drop git start typo compl" -- "${COMP_WORD[1]}"))
    fi
}
complete -o default -F _eza eza

_so(){
    if [[ COMP_CWORD -eq 1 ]]
    then
        _complete_db_name
    fi
}
complete -o default -F _so so
complete -o default -F _so soi
complete -o default -F _so sou
complete -o default -F _so godb
complete -o default -F _so goso
complete -o default -F _so clean_database
complete -o default -F _so neuter_db
complete -o default -F _so dropodoo
complete -o default -F _so lu

