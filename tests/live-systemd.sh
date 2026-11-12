#!/usr/bin/env bash
# Opt in only: creates uniquely named runtime user units and a private socket.
set -euo pipefail
[[ ${TMUX_MANAGER_LIVE_TEST:-} == 1 ]] || { echo 'SKIP: set TMUX_MANAGER_LIVE_TEST=1'; exit 0; }
cd "$(dirname "$0")/.."
root=$PWD
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-live.XXXXXXXX")
prefix="tmux-manager-test-$(basename "$scratch" | tr '[:upper:].' '[:lower:]-')"
unitdir="${XDG_RUNTIME_DIR:?}/systemd/user"
mkdir -p "$scratch/bin" "$scratch/conf" "$scratch/socket" "$scratch/home" "$unitdir"
export TMUX_TMPDIR="$scratch/socket" TMUX_MANAGER_CONF_DIR="$scratch/conf" TMUX_MANAGER_UNIT_PREFIX="$prefix"
unset TMUX TMUX_MANAGER_INTERNAL
real_systemctl=$(command -v systemctl)
real_tmux=$(command -v tmux)
export real_systemctl real_tmux
cat >"$scratch/bin/systemctl" <<'SH'
#!/usr/bin/env bash
if [[ $* == '--user show-environment' ]]; then
    printf 'TMUX_TMPDIR=%s\nTMUX_MANAGER_CONF_DIR=%s\nTMUX_MANAGER_UNIT_PREFIX=%s\n' "$TMUX_TMPDIR" "$TMUX_MANAGER_CONF_DIR" "$TMUX_MANAGER_UNIT_PREFIX"
else
    exec "$real_systemctl" "$@"
fi
SH
cat >"$scratch/bin/tmux" <<'SH'
#!/usr/bin/env bash
exec "$real_tmux" -f /dev/null "$@"
SH
cat >"$scratch/bin/loginctl" <<'SH'
#!/usr/bin/env bash
printf 'yes\n'
SH
chmod +x "$scratch/bin/systemctl" "$scratch/bin/loginctl" "$scratch/bin/tmux"
export PATH="$scratch/bin:$PATH"
cleanup() {
    "$real_systemctl" --user stop "$prefix-session@dev\\x2dtest\\x40x.service" "$prefix-session@two.service" "$prefix-server.service" 2>/dev/null || true
    tmux -L default kill-server 2>/dev/null || true
    rm -f "$unitdir/$prefix-server.service" "$unitdir/$prefix-session@.service"
    "$real_systemctl" --user daemon-reload || true
    rm -rf "$scratch"
}
trap cleanup EXIT
# The unit files exist only in the user's runtime directory and use unique names.
sed -e "s|/opt/tmux-manager/bin/tmux-manager|$root/bin/tmux-manager|g" \
    -e "/^Type=/a Environment=\"HOME=$scratch/home\" \"TMUX_TMPDIR=$TMUX_TMPDIR\" \"TMUX_MANAGER_CONF_DIR=$TMUX_MANAGER_CONF_DIR\" \"TMUX_MANAGER_UNIT_PREFIX=$prefix\" \"PATH=$PATH\" \"real_systemctl=$real_systemctl\" \"real_tmux=$real_tmux\"" \
    systemd/user/tmux-manager-server.service >"$unitdir/$prefix-server.service"
sed -e "s|/opt/tmux-manager/bin/tmux-manager|$root/bin/tmux-manager|g" \
    -e "s/tmux-manager-server.service/$prefix-server.service/g" \
    -e "/^Type=/a Environment=\"HOME=$scratch/home\" \"TMUX_TMPDIR=$TMUX_TMPDIR\" \"TMUX_MANAGER_CONF_DIR=$TMUX_MANAGER_CONF_DIR\" \"TMUX_MANAGER_UNIT_PREFIX=$prefix\" \"PATH=$PATH\" \"real_systemctl=$real_systemctl\" \"real_tmux=$real_tmux\"" \
    systemd/user/tmux-manager-session@.service >"$unitdir/$prefix-session@.service"
"$real_systemctl" --user daemon-reload
printf 'ENABLED=false\n' >"$TMUX_MANAGER_CONF_DIR/dev-test@x.conf"
printf 'ENABLED=true\n' >"$TMUX_MANAGER_CONF_DIR/two.conf"
bin/tmux-manager start 'dev-test@x'
bin/tmux-manager start two
pid=$(tmux -L default display-message -p '#{pid}')
id=$(tmux -L default display-message -p -t '=two' '#{session_id}')
bin/tmux-manager restart 'dev-test@x'
[[ $(tmux -L default display-message -p '#{pid}') == "$pid" ]]
[[ $(tmux -L default display-message -p -t '=two' '#{session_id}') == "$id" ]]
bin/tmux-manager stop 'dev-test@x'
bin/tmux-manager stop two
[[ $(tmux -L default display-message -p '#{pid}') == "$pid" ]]
"$real_systemctl" --user stop "$prefix-server.service"
tmux -L default -f /dev/null new-session -d -s foreign
if "$real_systemctl" --user start "$prefix-server.service"; then exit 1; fi
tmux -L default has-session -t '=foreign'
echo 'PASS: live isolated user-systemd ownership and session independence'
