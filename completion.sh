_complete_oe_dbs_name()
{
    local db_name
    for db_name in $(psql -tAqX -d postgres -c "SELECT t1.datname AS db_name FROM pg_database t1 WHERE t1.datname like 'oe_support_%' ORDER BY LOWER(t1.datname);")
    do
        COMPREPLY+=(${db_name:11})
    done
}

_complete_oe_2_part_params()
{
    case ${COMP_WORDS[COMP_CWORD-1]} in
        --port|-p)
            COMPREPLY=($(compgen -W "8569 8069 8888" "${COMP_WORDS[COMP_CWORD]}"))
            return 0
            ;;
        --python)
            COMPREPLY=($(compgen -W "python2 python3" "${COMP_WORDS[COMP_CWORD]}"))
            return 0
            ;;
        *)
            # standard autocomplete
            COMPREPLY=($(compgen -f))
            return 0
            ;;
    esac
}

_complete_oe_additional_params()
{
    if [[ ${COMP_WORDS[COMP_CWORD-1]} =~ ^(--port|-p|--src|-s|--internal|-i|--user|-u)$ ]]
    then
        _complete_oe_2_part_params
    else
        case ${COMP_WORDS[1]} in
            start)
                COMPREPLY=($(compgen -W "--filestore --no-start --no-checkout --port --debug --quiet --vscode --shell --user --no-keyring --src --internal --python" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            info)
                COMPREPLY=($(compgen -W "--user --no-keyring" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            restore)
                COMPREPLY=($(compgen -W "--no-start --no-checkout --port --debug --quiet --vscode --shell --src --internal --python" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            fetch)
                COMPREPLY=($(compgen -W "--filestore --no-start --no-checkout --port --debug --quiet --vscode --shell --user --no-keyring --src --internal --python" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            download)
                COMPREPLY=($(compgen -W "--filestore --quiet --user --no-keyring" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            cleanup)
                COMPREPLY=($(compgen -W "--quiet" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
            restore-dump)
                COMPREPLY=($(compgen -W "--no-start --no-checkout --port --debug --quiet --vscode --shell --remove-custo --src --internal --python" -- "${COMP_WORDS[COMP_CWORD]}"))
                return 0
                ;;
        esac
    fi
}

_oe-support()
{
    if [[ COMP_CWORD -eq 1 ]]
    then
        COMPREPLY=($(compgen -W "fetch download restore restore-dump start info list list-users cleanup config" "${COMP_WORDS[1]}"))
        return 0
    fi

    if [[ COMP_CWORD -eq 2 ]]
    then
        case ${COMP_WORDS[1]} in
            start|info|restore|fetch|download|list-users|restore-dump)
                _complete_oe_dbs_name
                return 0
                ;;
            config)
                COMPREPLY=($(compgen -W "user vacuum-delay port src internal no-start worktree-src" "${COMP_WORDS[2]}"))
                return 0
                ;;
            cleanup)
                _complete_oe_dbs_name
                COMPREPLY+=("--all")
                ;;
        esac
    fi

    if [[ COMP_CWORD -eq 3 ]]
    then
        if [ "${COMP_WORDS[1]}" = "restore-dump" ] || [ "${COMP_WORDS[1]}" = "config" ]
        then
            # standard autocomplete
            COMPREPLY=($(compgen -f))
            return 0
        else
            _complete_oe_additional_params
            return 0
        fi
    fi

    if [[ COMP_CWORD -gt 3 ]]
    then
        _complete_oe_additional_params
    fi
}

complete -F _oe-support oes
