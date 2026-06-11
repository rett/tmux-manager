#!/usr/bin/env bash
# Install tmux-manager: script to /opt/tmux-manager/bin, unit to
# /etc/systemd/system, convenience symlink in /usr/local/bin. Idempotent.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f $SRC/bin/tmux-manager || ! -f $SRC/systemd/tmux-manager@.service ]]; then
    echo "install.sh: cannot find project files under $SRC" >&2
    exit 1
fi

# /opt/tmux-manager may be a symlink to the source tree; don't copy onto itself.
if [[ "$(readlink -f /opt/tmux-manager)" == "$(readlink -f "$SRC")" ]]; then
    echo "install.sh: /opt/tmux-manager already points at $SRC, skipping copy"
    chmod 0755 "$SRC/bin/tmux-manager"
else
    install -d -m 0755 /opt/tmux-manager/bin
    install -m 0755 "$SRC/bin/tmux-manager" /opt/tmux-manager/bin/tmux-manager
fi
install -m 0644 "$SRC/systemd/tmux-manager@.service" /etc/systemd/system/tmux-manager@.service
install -D -m 0644 "$SRC/completions/tmux-manager.bash" /usr/share/bash-completion/completions/tmux-manager
ln -sfn /opt/tmux-manager/bin/tmux-manager /usr/local/bin/tmux-manager
systemctl daemon-reload

cat <<EOF
tmux-manager installed.

Next steps (per user):
  mkdir -p ~/.tmux-manager
  cp $SRC/examples/dev.conf ~/.tmux-manager/   # edit to taste
  sudo systemctl enable --now tmux-manager@${SUDO_USER:-<user>}

After upgrading, restart running instances:
  sudo systemctl try-restart 'tmux-manager@*'
EOF
