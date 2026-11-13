#!/usr/bin/env bash
# Install tmux-manager: script to /opt/tmux-manager/bin, unit to
# /etc/systemd/system, convenience symlink in /usr/local/bin. Idempotent.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f $SRC/bin/tmux-manager || ! -f $SRC/systemd/user/tmux-manager.service ]]; then
    echo "install.sh: cannot find project files under $SRC" >&2
    exit 1
fi

# Every existing component must be owned by root and protected from replacement.
trusted() {
    local path=$1 kind=$2 owner mode
    [[ ! -L $path ]] || { echo "install.sh: unsafe symlink: $path" >&2; return 1; }
    [[ -e $path ]] || return 0
    if [[ $kind == dir ]]; then [[ -d $path ]] || return 1
    else [[ -f $path ]] || return 1; fi
    read -r owner mode < <(stat -c '%u %a' -- "$path")
    if [[ $owner != 0 || ! $mode =~ ^[0-7]+$ ]] || (( (8#$mode & 0022) != 0 )); then
        echo "install.sh: untrusted destination: $path" >&2; return 1;
    fi
}
for dir in /opt /opt/tmux-manager /opt/tmux-manager/bin /opt/tmux-manager/lib /opt/tmux-manager/sbin; do
    trusted "$dir" dir || exit 1
done
for file in /opt/tmux-manager/bin/tmux-manager /opt/tmux-manager/sbin/tmux-manager-sudoers /opt/tmux-manager/lib/*.sh; do
    trusted "$file" file || exit 1
done
install -d -m 0755 /opt/tmux-manager/bin /opt/tmux-manager/lib
install -m 0755 "$SRC/bin/tmux-manager" /opt/tmux-manager/bin/tmux-manager
install -m 0644 "$SRC"/lib/*.sh /opt/tmux-manager/lib/
install -d -m 0755 /opt/tmux-manager/sbin
install -m 0755 "$SRC/scripts/tmux-manager-sudoers" /opt/tmux-manager/sbin/tmux-manager-sudoers
install -m 0644 "$SRC/systemd/tmux-manager@.service" /etc/systemd/system/tmux-manager@.service
install -D -m 0644 "$SRC/completions/tmux-manager.bash" /usr/share/bash-completion/completions/tmux-manager
ln -sfn /opt/tmux-manager/bin/tmux-manager /usr/local/bin/tmux-manager
install -d -m 0755 /etc/systemd/user
install -m 0644 "$SRC"/systemd/user/*.service /etc/systemd/user/
systemctl daemon-reload

cat <<EOF
tmux-manager installed.

Next steps (run the user commands as the target user):
  sudo loginctl enable-linger <user>
  systemctl --user daemon-reload
  systemctl --user enable --now tmux-manager.service

Migration: do not restart an existing system tmux-manager@<user> unit or kill
its server until every valuable session has finished. The new server refuses
to adopt an existing server. See README.md for planned migration steps.
EOF
