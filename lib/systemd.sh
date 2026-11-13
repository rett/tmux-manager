# shellcheck shell=bash
# systemd backend for tmux-manager (sourced by the CLI).
# Keep the default server separate from session lifecycle units. Every pane
# is forked by this server and therefore inherits its persistent cgroup.
service_unit() {
    systemd-escape --template="${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}-session@.service" -- "$1"
}

service_action() {
    local action=$1 name=$2 unit
    check_manager_environment || return 1
    unit=$(service_unit "$name") || return 1
    systemctl --user "$action" "$unit"
}

# Decode the shell-style quoting emitted by systemctl without evaluating it.
decode_environment_value() {
    local input=$1 out='' char quote='' i esc digits decoded
    for ((i=0; i<${#input}; i++)); do
        char=${input:i:1}
        if [[ $quote == ansi ]]; then
            if [[ $char == "'" ]]; then
                quote=
            elif [[ $char == \\ ]]; then
                ((i++)); ((i < ${#input})) || return 1
                esc=${input:i:1}
                case $esc in
                    a|b|e|E|f|n|r|t|v|\\) printf -v decoded '%b' "\\$esc" ;;
                    "'"|'"') decoded=$esc ;;
                    x)
                        digits=${input:i+1:2}
                        [[ $digits =~ ^[[:xdigit:]]{2}$ && $digits != 00 ]] || return 1
                        printf -v decoded '%b' "\\x$digits"
                        ((i+=2)) ;;
                    [0-7])
                        digits=${input:i:3}
                        [[ $digits =~ ^[0-7]{3}$ ]] || return 1
                        (( 8#$digits > 0 && 8#$digits <= 255 )) || return 1
                        printf -v decoded '%b' "\\0$digits"
                        ((i+=2)) ;;
                    *) return 1 ;;
                esac
                out+=$decoded
            else
                out+=$char
            fi
        elif [[ $quote == "'" ]]; then
            if [[ $char == "'" ]]; then quote=; else out+=$char; fi
        elif [[ $char == '$' && -z $quote && ${input:i+1:1} == "'" ]]; then
            quote=ansi
            ((i++))
        elif [[ $char == "'" && -z $quote ]]; then
            quote="'"
        elif [[ $char == '"' ]]; then
            if [[ -z $quote ]]; then quote='"'; else quote=; fi
        elif [[ $char == \\ ]]; then
            ((i++))
            ((i < ${#input})) || return 1
            out+=${input:i:1}
        else
            out+=$char
        fi
    done
    [[ -z $quote ]] || return 1
    REPLY=$out
}

# User services inherit the manager environment, not the invoking shell's.
check_manager_environment() {
    local env key value expected
    env=$(systemctl --user show-environment) || { warn "cannot read systemd user environment"; return 1; }
    for key in TMUX_MANAGER_CONF_DIR TMUX_TMPDIR TMUX_MANAGER_UNIT_PREFIX; do
        value=$(printf '%s\n' "$env" | sed -n "s/^${key}=//p")
        decode_environment_value "$value" || { warn "invalid systemd environment encoding for $key"; return 1; }
        value=$REPLY
        expected=${!key-}
        if [[ $value != "$expected" ]]; then
            warn "$key differs from the systemd user manager environment; configure it there before starting services"
            return 1
        fi
    done
}

require_persistence() {
    local linger
    check_manager_environment || return 1
    linger=$(loginctl show-user "$(id -u)" -p Linger --value) || { warn "cannot check lingering"; return 1; }
    [[ $linger == yes ]] || { warn "enable persistence first: sudo loginctl enable-linger $(id -un)"; return 1; }
}

require_backend() {
    require_persistence || return 1
    systemctl --user start "${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}-server.service" || return 1
    service_ready
}

service_start() {
    local name=$1
    require_backend || return 1
    # RemainAfterExit units may still be active after a session was killed
    # directly in tmux. Restart in that case to run ExecStart again.
    if session_running "$name"; then
        service_action start "$name"
    else
        service_action restart "$name"
    fi
}

service_server() {
    # Refuse to adopt or kill an existing server: it may own valuable sessions.
    if tmux display-message -p '#{pid}' >/dev/null 2>&1; then
        warn "a tmux server already exists outside this service; migrate it during planned downtime"
        return 1
    fi
    unset TMUX
    exec tmux -L default -D
}

service_ready() {
    local expected actual attempt
    expected=$(systemctl --user show "${TMUX_MANAGER_UNIT_PREFIX:-tmux-manager}-server.service" -p MainPID --value) || return 1
    [[ $expected =~ ^[1-9][0-9]*$ ]] || return 1
    for ((attempt=0; attempt<50; attempt++)); do
        actual=$(tmux display-message -p '#{pid}' 2>/dev/null) || actual=
        [[ $actual == "$expected" ]] && return 0
        sleep 0.1
    done
    warn "default tmux server is not owned by the server service; existing sessions were left untouched"
    return 1
}
