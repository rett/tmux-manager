# shellcheck shell=bash
real_user() {
    local uid record name
    uid=$(id -ru) || return 1
    record=$(getent passwd "$uid") || { warn 'cannot resolve real user'; return 1; }
    name=${record%%:*}
    [[ $name =~ ^[a-z_][a-z0-9_-]*$ ]] || { warn 'unsafe user name'; return 1; }
    REPLY=$name
}

cmd_setup() {
    real_user || return 1
    /usr/bin/sudo -n /usr/bin/loginctl enable-linger "$REPLY" || {
        warn 'cannot enable linger; install the exact sudoers rule or ask an administrator'
        return 1
    }
    systemctl --user daemon-reload || return 1
    systemctl --user enable --now "${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}.service"
}

cmd_sudoers() {
    [[ $# -eq 1 ]] || die 'usage: tmux-manager sudoers preview|check|install|remove'
    real_user || return 1
    case $1 in
        preview) printf '%s ALL=(root) NOPASSWD: /usr/bin/loginctl enable-linger %s\n' "$REPLY" "$REPLY" ;;
        check) /usr/bin/sudo -n -l /usr/bin/loginctl enable-linger "$REPLY" >/dev/null || { warn 'linger rule is unavailable'; return 1; } ;;
        install|remove)
            warn "run the one-time administrator action: sudo /opt/tmux-manager/sbin/tmux-manager-sudoers $1"
            return 1 ;;
        *) die 'usage: tmux-manager sudoers preview|check|install|remove' ;;
    esac
}

cmd_sessions_json() {
    local conf sep=''
    printf '['
    for conf in "$CONF_DIR"/*.conf; do
        [[ -e $conf ]] || break
        load_config "$conf" || return 1
        printf '%s"%s"' "$sep" "$CFG_SESSION_NAME"
        sep=,
    done
    printf ']\n'
}
