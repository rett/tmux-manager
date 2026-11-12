#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tmux-manager-dispatch.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin" "$scratch/conf with ' quote"
export TMUX_MANAGER_CONF_DIR="$scratch/conf with ' quote" TMUX_TMPDIR="$scratch/socket with space" CALLS="$scratch/calls"
export PATH="$scratch/bin:$PATH"
unset TMUX TMUX_MANAGER_INTERNAL TMUX_MANAGER_UNIT_PREFIX
cat >"$scratch/bin/tmux" <<'SH'
#!/usr/bin/env bash
printf 'tmux %s\n' "$*" >>"$CALLS"
case " $* " in
  *' display-message '*) printf '123\n' ;;
  *' has-session '*) [[ ${TEST_RUNNING:-0} == 1 ]] ;;
esac
SH
cat >"$scratch/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALLS"
case " $* " in
  *' show-environment '*)
    if [[ -n ${TEST_CONF:-} ]]; then printf 'TMUX_MANAGER_CONF_DIR=%s\n' "$TEST_CONF"; else printf 'TMUX_MANAGER_CONF_DIR=%q\n' "$TMUX_MANAGER_CONF_DIR"; fi
    printf 'TMUX_TMPDIR=%q\n' "$TMUX_TMPDIR" ;;
  *' MainPID '*) printf '%s\n' "${TEST_PID:-123}" ;;
  *' ActiveState '*) printf 'active\n' ;;
  *' UnitFileState '*) printf 'enabled\n' ;;
  *' stop '*) [[ ${FAIL_STOP:-0} != 1 ]] ;;
esac
SH
cat >"$scratch/bin/loginctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${TEST_LINGER:-yes}"
SH
chmod +x "$scratch/bin/"*
printf '#!/usr/bin/env bash\nexit 0\n' >"$scratch/bin/sleep"
chmod +x "$scratch/bin/sleep"
printf 'ENABLED=false\n' >"$TMUX_MANAGER_CONF_DIR/dev-test@x.conf"
printf 'ENABLED=true\n' >"$TMUX_MANAGER_CONF_DIR/other.conf"
bin/tmux-manager start 'dev-test@x'
grep -Fq 'restart tmux-manager-session@dev\x2dtest\x40x.service' "$CALLS"
bin/tmux-manager restart other
bin/tmux-manager stop other
grep -Fq 'stop tmux-manager-session@other.service' "$CALLS"
if TEST_LINGER=no bin/tmux-manager start other; then exit 1; fi
if TEST_CONF=/different bin/tmux-manager start other; then exit 1; fi
encoded_conf=${TMUX_MANAGER_CONF_DIR//\'/\'\\\'\'}
TEST_CONF="'$encoded_conf'" bin/tmux-manager start other
if TEST_CONF="'$TMUX_MANAGER_CONF_DIR" bin/tmux-manager start other; then exit 1; fi
if TEST_PID=1 bin/tmux-manager start other; then exit 1; fi
if FAIL_STOP=1 bin/tmux-manager shutdown; then exit 1; fi
if bin/tmux-manager stop unmanaged; then exit 1; fi
TEST_RUNNING=1 bin/tmux-manager attach other
TMUX=/foreign/socket,1,2 TEST_RUNNING=1 bin/tmux-manager attach other
grep -Fq 'attach-session -t =other' "$CALLS"
[[ $(bin/tmux-manager service status boot --json) == '{"target":"boot","active":"active","enabled":"enabled"}' ]]
bin/tmux-manager service restart server
grep -Fq 'systemctl --user restart tmux-manager-server.service' "$CALLS"
bin/tmux-manager service status session other --json | grep -Fq '"name":"other"'
[[ $(bin/tmux-manager sessions --json) == '["dev-test@x","other"]' ]]
if bin/tmux-manager service restart session other; then exit 1; fi
echo 'PASS: mocked dispatch, disabled start, linger and shutdown failures'
