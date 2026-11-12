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

# shellcheck source=lib/systemd.sh
source lib/systemd.sh
assert_decode() {
    decode_environment_value "$1" || exit 1
    [[ $REPLY == "$2" ]] || exit 1
}
assert_decode "\$'space path'" 'space path'
assert_decode "\$'it\\'s \\\\ \$HOME'" "it's \\ \$HOME"
assert_decode "\$'a\\nb\\t\\x21\\041'" $'a\nb\t!!'
assert_decode "\$'literal \$(touch /never)'" "literal \$(touch /never)"
assert_decode "'old'\\ path" 'old path'
for encoded in "\$'bad\\x00'" "\$'bad\\000'" "\$'bad\\x1'" "\$'bad\\q'" "\$'unfinished" "\$'bad\\"; do
    if decode_environment_value "$encoded"; then exit 1; fi
done
echo 'PASS: safe systemd ANSI-C environment decoding'
