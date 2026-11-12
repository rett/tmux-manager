#!/usr/bin/env bash
# Exercise the administrator helper in a temporary simulated sudoers directory.
set -euo pipefail
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-installer.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/policy" "$scratch/bin"
cat >"$scratch/bin/getent" <<'SH'
#!/bin/bash
printf 'testuser:x:1234:1234::/nonexistent:/bin/false\n'
SH
cat >"$scratch/bin/stat" <<'SH'
#!/bin/bash
if [[ $2 == '%u:%g:%a' ]]; then
    printf '0:0:%s\n' "$(/usr/bin/stat -c %a "$3")"
else
    printf '0:%s:%s\n' "$(/usr/bin/stat -c %a "$3")" "$(/usr/bin/stat -c %h "$3")"
fi
SH
cat >"$scratch/bin/chown" <<'SH'
#!/bin/bash
exit 0
SH
chmod +x "$scratch/bin/"*
chmod 755 "$scratch/policy"
# Replace only privileged operations and the destination; the policy generation,
# visudo invocation, file checks, and atomic move remain the production code.
# shellcheck disable=SC2016 # Match the literal source expression.
sed -e 's/\$EUID -eq 0/1 -eq 1/' \
    -e "s|dir=/etc/sudoers.d|dir=$scratch/policy|" \
    -e "s|/usr/bin/getent|$scratch/bin/getent|g" \
    -e "s|/usr/bin/stat|$scratch/bin/stat|g" \
    -e "s|/usr/bin/chown|$scratch/bin/chown|g" \
    scripts/tmux-manager-sudoers >"$scratch/helper"
export SUDO_UID=1234 SUDO_USER=testuser
bash "$scratch/helper" install
dest=$scratch/policy/tmux-manager-testuser
[[ -f $dest && $(stat -c %a "$dest") == 440 ]]
/usr/sbin/visudo -c -f "$dest"
bash "$scratch/helper" install
bash "$scratch/helper" remove
[[ ! -e $dest ]]
if bash "$scratch/helper" remove; then exit 1; fi
printf 'unrelated\n' >"$dest"
chmod 440 "$dest"
if bash "$scratch/helper" install; then exit 1; fi
if bash "$scratch/helper" remove; then exit 1; fi
[[ $(cat "$dest") == unrelated ]]
rm "$dest"
ln -s "$scratch/target" "$dest"
if bash "$scratch/helper" install; then exit 1; fi
[[ -L $dest && ! -e $scratch/target ]]
if SUDO_USER='bad,user' bash "$scratch/helper" install; then exit 1; fi
if bash "$scratch/helper" install extra; then exit 1; fi
echo 'PASS: simulated administrator helper destination safety'
