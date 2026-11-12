#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-review.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/install/bin" "$scratch/install/lib" "$scratch/link"
cp bin/tmux-manager "$scratch/install/bin/"
cp lib/*.sh "$scratch/install/lib/"
ln -s ../install/bin/tmux-manager "$scratch/link/tmux-manager"
"$scratch/link/tmux-manager" help >/dev/null
rm "$scratch/install/lib/admin.sh"
if "$scratch/link/tmux-manager" help >/dev/null 2>&1; then exit 1; fi
echo 'PASS: symlinked executable and library failure'

# Exercise the installer's real trust predicate with simulated ownership.
sed -n '/^trusted() {/,/^}/p' scripts/install.sh >"$scratch/trusted.sh"
mkdir -p "$scratch/mock" "$scratch/opt/tmux-manager/sbin"
cat >"$scratch/mock/stat" <<'SH'
#!/usr/bin/env bash
if [[ ${UNTRUSTED:-} == "${*: -1}" ]]; then printf '1000 755\n'; else /usr/bin/stat "$@" | sed 's/^[0-9]* /0 /'; fi
SH
chmod +x "$scratch/mock/stat"
export PATH="$scratch/mock:$PATH"
# shellcheck source=/dev/null
source "$scratch/trusted.sh"
trusted "$scratch/opt" dir
trusted "$scratch/opt/tmux-manager/sbin" dir
UNTRUSTED="$scratch/opt/tmux-manager"; export UNTRUSTED
if trusted "$UNTRUSTED" dir; then exit 1; fi
unset UNTRUSTED
ln -s "$scratch/opt/tmux-manager" "$scratch/opt/link"
if trusted "$scratch/opt/link" dir; then exit 1; fi
ln -s /nonexistent "$scratch/opt/tmux-manager/sbin/tmux-manager-sudoers"
if trusted "$scratch/opt/tmux-manager/sbin/tmux-manager-sudoers" file; then exit 1; fi
echo 'PASS: simulated installer trust checks'
