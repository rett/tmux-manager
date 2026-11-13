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

doctor_path="$scratch/doctor-bin:$PATH"

# A shell wrapper must not satisfy the executable prerequisite.
mkdir "$scratch/empty"
sed -n '/^require_tmux() {/,/^}/p' bin/tmux-manager >"$scratch/require-tmux.sh"
# The isolated PATH and functions model a wrapper without an executable.
# The sourced probe calls die indirectly, which older ShellCheck cannot trace.
# shellcheck disable=SC2123,SC2329,SC1091,SC2317
if ( PATH="$scratch/empty"; tmux() { :; }; die() { exit 1; }; \
     source "$scratch/require-tmux.sh"; require_tmux ); then exit 1; fi
echo 'PASS: missing tmux executable is detected'

mkdir "$scratch/packages"
for manager in pacman apt-get; do
    touch "$scratch/packages/$manager"
    chmod +x "$scratch/packages/$manager"
    PATH="$scratch/packages" /usr/bin/make -n bootstrap >"$scratch/preview"
    grep -Fq "sudo $manager " "$scratch/preview"
done
rm "$scratch/packages/"*
if PATH="$scratch/packages" /usr/bin/make bootstrap >"$scratch/preview" 2>&1; then exit 1; fi
grep -Fq 'unsupported:' "$scratch/preview"
echo 'PASS: mocked package manager detection and dry-run'

# Older tmux prints an unsupported -h diagnostic before its usage line.
mkdir "$scratch/doctor-bin"
cat >"$scratch/doctor-bin/tmux" <<'SH'
#!/bin/bash
case $1 in
    -V) printf 'tmux 3.4\n' ;;
    -h)
        printf 'tmux: unknown option -- h\n' >&2
        if [[ ${TEST_TMUX_NO_N:-0} == 1 ]]; then
            printf 'usage: tmux [-2CDluVv] [command [flags]]\n' >&2
        else
            printf 'usage: tmux [-2CDlNuVv] [command [flags]]\n' >&2
        fi
        exit 1 ;;
    *) exit 1 ;;
esac
SH
chmod +x "$scratch/doctor-bin/tmux"
PATH="$doctor_path" make doctor >"$scratch/doctor-output"
grep -Fq 'ok: tmux supports -N' "$scratch/doctor-output"
if TEST_TMUX_NO_N=1 PATH="$doctor_path" make doctor >"$scratch/doctor-output" 2>&1; then exit 1; fi
grep -Fq 'fail: tmux lacks -N' "$scratch/doctor-output"
echo 'PASS: tmux 3.4 usage detection and unsupported option rejection'
