#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n bin/tmux-manager lib/*.sh scripts/install.sh scripts/tmux-manager-sudoers tests/*.sh
shellcheck -x bin/tmux-manager lib/*.sh scripts/install.sh scripts/tmux-manager-sudoers completions/tmux-manager.bash tests/*.sh
echo 'PASS: static checks'
