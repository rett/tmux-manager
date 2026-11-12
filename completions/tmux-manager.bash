# bash completion for tmux-manager
_tmux_manager() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local commands="list enable disable start stop restart attach rename sessions boot shutdown service sudoers help"
    COMPREPLY=()

    if [[ $COMP_CWORD -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
        return
    fi

    case ${COMP_WORDS[1]} in
        service)
            case $COMP_CWORD in
                2) mapfile -t COMPREPLY < <(compgen -W 'status start stop restart enable disable setup' -- "$cur") ;;
                3) mapfile -t COMPREPLY < <(compgen -W 'boot server session' -- "$cur") ;;
            esac ;;
        sudoers) [[ $COMP_CWORD -ne 2 ]] || mapfile -t COMPREPLY < <(compgen -W 'preview check install remove' -- "$cur") ;;
        enable | disable | start | stop | restart | attach | rename)
            # rename's third argument is the new (free-form) name.
            if [[ $COMP_CWORD -eq 2 ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$(tmux-manager sessions 2>/dev/null)" -- "$cur")
            fi
            ;;
    esac
}
complete -F _tmux_manager tmux-manager
