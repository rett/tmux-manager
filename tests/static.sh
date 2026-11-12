#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n bin/tmux-manager lib/*.sh scripts/install.sh tests/*.sh
shellcheck -x bin/tmux-manager lib/*.sh scripts/install.sh completions/tmux-manager.bash tests/*.sh
echo 'PASS: static checks'
