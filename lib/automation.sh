# shellcheck shell=bash
# Explicit user-unit control. Session lifecycle commands remain separate.
cmd_service() {
    local action=${1:-} target=${2:-} unit name state enabled
    shift $(( $# >= 2 ? 2 : $# ))
    case $target in
        boot) unit="${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}.service" ;;
        server) unit="${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}-server.service" ;;
        session)
            [[ $action == status && $# -ge 1 ]] || die 'usage: tmux-manager service status session NAME [--json]'
            name=$1; shift
            resolve_conf "$name" >/dev/null || return 1
            unit=$(service_unit "$name") || return 1 ;;
        *) die 'usage: tmux-manager service ACTION boot|server' ;;
    esac
    case $action in
        status)
            if [[ ${1:-} == --json && $# -eq 1 ]]; then
                state=$(systemctl --user show "$unit" -p ActiveState --value) || return 1
                enabled=$(systemctl --user show "$unit" -p UnitFileState --value) || return 1
                [[ $state =~ ^[a-z-]*$ && $enabled =~ ^[a-z-]*$ ]] || { warn 'invalid service state'; return 1; }
                printf '{"target":"%s","active":"%s","enabled":"%s"}\n' "$target" "$state" "$enabled"
            elif [[ $# -eq 0 ]]; then
                systemctl --user --no-pager status "$unit"
            else
                die 'usage: tmux-manager service status boot|server|session NAME [--json]'
            fi ;;
        start|stop|restart|enable|disable)
            [[ $# -eq 0 && $target != session ]] || die 'invalid service arguments'
            systemctl --user "$action" "$unit" ;;
        *) die 'unknown service action' ;;
    esac
}
