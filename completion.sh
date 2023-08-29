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
        #TODO: use shift maybe?
    fi
}

####################################
####    completion 'bricks'    #####
####################################

_complete_db_name() {
    local db_names=$(list_db_like "%%" | sed '/CLEAN*/d' | sed '/template*/d' | sed '/meta/d' | sed '/postgres/d' | tr '\n' ' ')
    COMPREPLY=($(compgen -W "$db_names" -- "${COMP_WORD[COMP_CWORD]}"))
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
        COMPREPLY=($(compgen -W "shell py loader drop git compl vim tig utils tmp typo" -- "${COMP_WORD[1]}"))
    fi
    if [[ COMP_CWORD -eq 2 ]]; then
        local function_names=" "
        case ${COMP_WORDS[1]} in
        shell)
            function_names=$(grep ".*() {" $AP/alias.sh | sed 's/() {*//' | tr '\n' ' ')
            ;;
        loader)
            function_names=$(grep "export " $AP/alias_loader.sh | sed 's/export //' | awk -F '=' '{print $1}' | tr '\n' ' ')
            ;;
        py)
            function_names=$(grep "^def .*):" $AP/python_scripts/alias.py | sed 's/def //' | sed 's/(.*)*//' | tr '\n' ' ')
            ;;
        git)
            function_names=$(grep "^def .*):" $AP/python_scripts/git_odoo.py | sed 's/def //' | sed 's/(.*)*//' | tr '\n' ' ')
            ;;
        compl)
            function_names=$(grep ".*() {" $AP/completion.sh | grep -v "function_names" | sed 's/() {*//' | tr '\n' ' ')
            ;;
        tmp)
            function_names=$(grep ".*() {" $AP/temporary-scripts.sh | sed 's/() {*//' | tr '\n' ' ')
            ;;
        *) ;;

        esac
        COMPREPLY=($(compgen -W "$function_names" -- "${COMP_WORD[COMP_CWORD]}"))
    fi
}
complete -o default -F _eza eza
complete -o default -F _eza ewq

_so() {
    _complete_db_name_on_first_param
    if [[ COMP_CWORD -eq 2 ]]; then
        COMPREPLY=($(compgen -W "8569 8069 8888" -- "${COMP_WORDS[COMP_CWORD]}"))
    fi
}
complete -o default -F _so so
complete -o default -F _so soi
complete -o default -F _so sou
complete -o default -F _so goso
complete -o default -F _so ptvsd3-so
complete -o default -F _so ptvsd2-so

complete -o default -F _complete_db_name_on_first_param godb
complete -o default -F _complete_db_name_on_first_param clean_database
complete -o default -F _complete_db_name dropodoo
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

_clear_pyc() {
    if [[ COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "--all" -- "${COMP_WORD[COMP_CWORD]}"))
    fi
}
complete -o default -F _clear_pyc clear_pyc

_neuter_db() {
    _complete_db_name_on_first_param
    if [[ COMP_CWORD -eq 2 ]]; then
        COMPREPLY=($(compgen -W "--minimal" -- "${COMP_WORDS[COMP_CWORD]}"))
    fi
}
complete -o default -F _neuter_db neuter_db

########################################################
####    customized completion for other scripts    #####
########################################################

# odev tab completion script
# Version:  0.3
# Install:  Link the script into /usr/share/bash-completions/completions/
#           or ~/.local/share/bash-completions/completions/
#           'source' the file to use the features in the current session.
# Features: Tab completion on commands, databases and filenames.
#           ?<TAB> at any point will display help on the current command and
#             redisplay the command line.
#           odev run -[i|u] <TAB> will offer directory names (modules) as options,
#             excluding ./util_package and ./psbe-internal.
#           odev run -[i|u] *<TAB> will put a csv of custom modules on the command line.

_odev() { #  By convention, the function name starts with an underscore.
    _odev_complete_config="${HOME}/.config/odev/databases.cfg"

    _odev_complete_list_cache() {
        # if [ "${_odev_complete_last:-0}" -lt "$(date +%s -r ${_odev_complete_config})" ]; then
        _odev_complete_list="$(odev list -1)"
        _odev_complete_last="$(date +%s)"
        # fi
    }

    local cur prev words cword split opts
    # _init_completion -s || return

    if [ "$cur" = "?" ]; then
        cmd="${words[@]:0:cword} --help"
        $cmd
        # replace '?' and fake an option to force redraw-current-line after help text
        COMPREPLY=(" " "  ")
        return
    fi

    case ${COMP_CWORD} in
    1)
        # complete command names
        if [ -z "${_odev_complete_help}" ]; then
            _odev_complete_help="$(odev help -1)"
        fi
        opts=${_odev_complete_help}
        ;;
    2)
        # complete database names
        _odev_complete_list_cache
        opts=${_odev_complete_list}
        ;;
    3)
        # complete template names
        if [ "${words[1]}" = "create" ]; then
            _odev_complete_list_cache
            opts=${_odev_complete_list}
        fi
        ;;
    4)
        # complete custom module/directory names
        if [ "$prev" = "-i" -o "$prev" = "-u" ]; then
            # glob on './*' to avoid any '.*' files/dirs
            opts=(./*)
            for o in "${!opts[@]}"; do
                # remove files or special directories
                if [ ! -d ${opts[o]} -o "${opts[o]}" = "./util_package" -o "${opts[o]}" = "./psbe-internal" ]; then
                    unset opts[o]
                else
                    # removing leading ./
                    opts[$o]=${opts[o]#./}
                fi
            done
            # convert array to wordlist
            opts="${opts[@]}"
            # replace '*' with a csv of all module names
            if [ "$cur" = "*" ]; then
                COMPREPLY=($(echo "${opts}" | tr ' ' ','))
                return
            fi
        fi
        ;;
    *)
        _filedir
        return
        ;;
    esac

    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))

    return
} &&
    complete -F _odev -o default odev
