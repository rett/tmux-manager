# bash completion for tmux-manager
_tmux_manager() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local commands="list enable disable start stop restart attach rename sessions boot shutdown help"
    COMPREPLY=()

    if [[ $COMP_CWORD -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
        return
    fi

    case ${COMP_WORDS[1]} in
        enable | disable | start | stop | restart | attach | rename)
            # rename's third argument is the new (free-form) name.
            if [[ $COMP_CWORD -eq 2 ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$(tmux-manager sessions 2>/dev/null)" -- "$cur")
            fi
            ;;
    esac
}
complete -F _tmux_manager tmux-manager
