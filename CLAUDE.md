# tmux-manager

Systemd-managed per-user tmux sessions. A system-level template unit
(`tmux-manager@<user>.service`) starts each user's enabled tmux sessions at
boot from config files in `~/.tmux-manager/*.conf`, managed by the
`tmux-manager` CLI.

## Layout

- `bin/tmux-manager` — bash CLI: `boot`/`shutdown` (called by the unit), `list`, `enable`, `disable`, `start`, `stop`, `attach`, `rename`, `sessions`
- `systemd/tmux-manager@.service` — system template unit (`Type=oneshot`, `RemainAfterExit=yes`, `User=%i`)
- `completions/tmux-manager.bash` — bash completion (installed to `/usr/share/bash-completion/completions/tmux-manager`)
- `examples/*.conf` — sample session configs
- `scripts/install.sh` — installs to `/opt/tmux-manager/bin`, `/etc/systemd/system`, and symlinks into `/usr/local/bin`

## Key paths

- Session configs: `~/.tmux-manager/*.conf` (override with `TMUX_MANAGER_CONF_DIR`)
- Installed script: `/opt/tmux-manager/bin/tmux-manager`
- Unit: `/etc/systemd/system/tmux-manager@.service`; enable per user with `sudo systemctl enable --now tmux-manager@<user>`

## Conventions

- tmux session targets always use exact-match syntax (`-t "=$name"`); windows are targeted by captured `#{window_id}`, never by index or name.
- The CLI uses `set -uo pipefail` without `-e` (expected-nonzero tmux/grep calls); errors are handled explicitly with `|| return 1` / `die`.
- Window commands are sent with `send-keys -l` plus a separate `Enter`, so the window survives command exit and key-name tokens stay literal.
- Server placement for logout survival: the *first* `new-session` (the one that may spawn the server) goes through `ensure_server_launch`/`SERVER_LAUNCH`. Interactively it is wrapped in `systemd-run --user --scope` so the server lands under `user@<uid>.service` (needs lingering) instead of the ephemeral SSH `session-NNN.scope`, which logind reaps under `KillUserProcesses=yes`. The unit sets `TMUX_MANAGER_FROM_UNIT=1` to skip the wrapper and keep the server in its own `system.slice` cgroup. Best-effort: falls back to a bare `tmux` when no user manager is reachable.
- Keep files under 500 lines.

## Testing

- Static: `bash -n bin/tmux-manager scripts/install.sh`; `shellcheck` both.
- Isolated functional test (touches neither the real tmux server nor real configs):
  `export TMUX_TMPDIR=$(mktemp -d) TMUX_MANAGER_CONF_DIR=$(mktemp -d)`, copy
  `examples/*.conf` into the conf dir, then exercise `list`, `start`, `stop`,
  `boot`, `shutdown`, `enable`, `disable`.
- Unit-level: `scripts/install.sh`, `sudo systemctl start tmux-manager@<user>`,
  inspect `journalctl -u tmux-manager@<user>` and `tmux ls`.

## Git

- git-flow: `master` holds releases, `develop` is the integration branch; feature branches come off `develop`.
- Never reference Claude or AI assistance in commit messages, attributions, or comments.
