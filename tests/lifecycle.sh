#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-lifecycle.XXXXXXXX")
export TMUX_TMPDIR="$scratch" TMUX_MANAGER_CONF_DIR="$scratch/conf" TMUX_MANAGER_INTERNAL=session
unset TMUX
mkdir "$TMUX_MANAGER_CONF_DIR"
cleanup() { tmux -L default kill-server 2>/dev/null || true; rm -rf "$scratch"; }
trap cleanup EXIT
tmux -L default -f /dev/null start-server \; set-option -g exit-empty off
printf 'ENABLED=true\nWINDOW=shell\nWINDOW=second\n' >"$TMUX_MANAGER_CONF_DIR/dev.conf"
printf 'ENABLED=false\n' >"$TMUX_MANAGER_CONF_DIR/dev2.conf"
bin/tmux-manager start dev
bin/tmux-manager start dev2
tmux -L default new-session -d -s unmanaged
before=$(tmux -L default display-message -p -t '=dev2' '#{session_id}')
bin/tmux-manager stop dev
[[ $(tmux -L default display-message -p -t '=dev2' '#{session_id}') == "$before" ]]
bin/tmux-manager start dev
[[ $(tmux -L default list-windows -t '=dev' -F '#{window_id}' | wc -l) -eq 2 ]]
if bin/tmux-manager stop unmanaged; then exit 1; fi
bin/tmux-manager shutdown
tmux -L default has-session -t '=unmanaged'
if tmux -L default has-session -t '=dev' 2>/dev/null; then exit 1; fi
if tmux -L default has-session -t '=dev2' 2>/dev/null; then exit 1; fi
echo 'PASS: isolated lifecycle'
