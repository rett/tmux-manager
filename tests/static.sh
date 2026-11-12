#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n bin/tmux-manager scripts/install.sh
shellcheck -x -e SC2015 bin/tmux-manager scripts/install.sh completions/tmux-manager.bash
echo 'PASS: static checks'
