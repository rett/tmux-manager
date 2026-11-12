#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-admin.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
# shellcheck source=lib/admin.sh
source lib/admin.sh
warn() { printf '%s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }
id() { [[ $1 == -ru ]]; printf '1234\n'; }
getent() { printf '%s:x:1234:1234::/nonexistent:/bin/false\n' "${TEST_USER:-testuser}"; }
systemctl() { printf 'systemctl %s\n' "$*" >>"$scratch/calls"; }
function /usr/bin/sudo() {
    printf 'sudo %s\n' "$*" >>"$scratch/calls"
    [[ ${FAIL_SUDO:-0} != 1 ]]
}
cmd_sudoers preview >"$scratch/policy"
[[ $(cat "$scratch/policy") == 'testuser ALL=(root) NOPASSWD: /usr/bin/loginctl enable-linger testuser' ]]
visudo -c -f "$scratch/policy"
cmd_setup
grep -Fxq 'sudo -n /usr/bin/loginctl enable-linger testuser' "$scratch/calls"
grep -Fxq 'systemctl --user enable --now tmux-manager.service' "$scratch/calls"
: >"$scratch/calls"
if FAIL_SUDO=1 cmd_setup; then exit 1; fi
if grep -q systemctl "$scratch/calls"; then exit 1; fi
if TEST_USER='bad,ALL' cmd_sudoers preview; then exit 1; fi
if (cmd_sudoers preview extra); then exit 1; fi
if (cmd_sudoers invalid); then exit 1; fi
cmd_sudoers install
cmd_sudoers remove
grep -Fxq 'sudo -n /opt/tmux-manager/sbin/tmux-manager-sudoers install' "$scratch/calls"
grep -Fxq 'sudo -n /opt/tmux-manager/sbin/tmux-manager-sudoers remove' "$scratch/calls"
if FAIL_SUDO=1 cmd_sudoers install; then exit 1; fi
bash tests/admin-installer.sh
echo 'PASS: exact sudoers policy and noninteractive setup'
