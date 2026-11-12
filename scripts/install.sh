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

# /opt/tmux-manager may be a symlink to the source tree; don't copy onto itself.
if [[ "$(readlink -f /opt/tmux-manager)" == "$(readlink -f "$SRC")" ]]; then
    echo "install.sh: /opt/tmux-manager already points at $SRC, skipping copy"
    chmod 0755 "$SRC/bin/tmux-manager"
else
    install -d -m 0755 /opt/tmux-manager/bin /opt/tmux-manager/lib
    install -m 0755 "$SRC/bin/tmux-manager" /opt/tmux-manager/bin/tmux-manager
    install -m 0644 "$SRC"/lib/*.sh /opt/tmux-manager/lib/
fi
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
