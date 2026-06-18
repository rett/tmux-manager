# tmux-manager

Systemd-managed per-user tmux sessions.

A system-level systemd template unit (`tmux-manager@<user>.service`) starts a
user's tmux sessions at boot, with each session described by a small config
file in `~/.tmux-manager/`. A companion CLI manages the lifecycle: list,
enable/disable at boot, start, stop, rename, and attach.

No extra daemon, no separate socket — sessions run on the user's normal tmux
server (the default `/tmp/tmux-<uid>/default` socket), so plain `tmux ls` and
`tmux attach` work exactly as you'd expect. They are also placed in a cgroup
that outlives your SSH session, so they survive logout (see
[Persistence across logout](#persistence-across-logout)).

## How it works

- `tmux-manager@.service` is a system template unit instanced per user:
  `tmux-manager@alice.service` runs as `User=alice` and is pulled in by
  `multi-user.target` at boot.
- At start, the unit runs `tmux-manager boot`, which reads every
  `~/.tmux-manager/*.conf` with `ENABLED=true` and creates the corresponding
  tmux sessions (windows, commands, and optional raw tmux post-commands).
- The unit is `Type=oneshot` with `RemainAfterExit=yes`: the boot script
  exits, the tmux server it spawned keeps running in the unit's cgroup.
- Sessions land on the user's **default** tmux socket
  (`/tmp/tmux-<uid>/default`), so they are indistinguishable from sessions
  you start by hand.

## Requirements

- Linux with systemd ≥ 240 (tested on systemd 255)
- tmux (tested on tmux 3.4)
- bash ≥ 4.4

## Installation

```sh
git clone https://github.com/rett/tmux-manager.git
cd tmux-manager
./scripts/install.sh
```

The installer (auto-elevates with sudo) puts things at:

| Path | Purpose |
|---|---|
| `/opt/tmux-manager/bin/tmux-manager` | the CLI |
| `/usr/local/bin/tmux-manager` | convenience symlink |
| `/etc/systemd/system/tmux-manager@.service` | the template unit |
| `/usr/share/bash-completion/completions/tmux-manager` | bash completion |

It is idempotent — re-run it after upgrades, then restart running instances:

```sh
sudo systemctl try-restart 'tmux-manager@*'
```

## Quick start

```sh
# 1. Create a session config
mkdir -p ~/.tmux-manager
cp examples/dev.conf ~/.tmux-manager/   # edit to taste

# 2. Try it now
tmux-manager start dev
tmux-manager attach dev

# 3. Enable the unit for your user so sessions start at boot
sudo systemctl enable --now tmux-manager@$USER
```

## Session config reference

One file per session in `~/.tmux-manager/<name>.conf`. Lines are
`KEY=VALUE`; values are literal to end of line (no quoting). Only full-line
`#` comments are supported, since `#` may legitimately appear inside
commands.

| Key | Repeatable | Default | Meaning |
|---|---|---|---|
| `SESSION_NAME` | no | conf filename minus `.conf` | tmux session name (`A-Za-z0-9_@-` only) |
| `START_DIR` | no | `$HOME` | working directory (`~` and `$HOME` expand) |
| `ENABLED` | no | `false` | start this session at boot |
| `WINDOW` | yes | one shell window | `name:command` — window running `command`; omit the colon for a plain shell |
| `POST_CMD` | yes | — | raw tmux command run after the session is created |

Window commands are typed into a normal shell (`send-keys`), so the window
survives when the command exits. The command may contain colons — only the
first colon separates the name.

`POST_CMD` lines give you full tmux power for layouts. They run in file
order after all windows exist. Use exact-match targets (`=name`) to avoid
tmux's prefix matching.

### Example

```ini
# ~/.tmux-manager/dev.conf
SESSION_NAME=dev
START_DIR=~/projects
ENABLED=true

WINDOW=edit:vim .
WINDOW=serve:python3 -m http.server 8080
WINDOW=shell

POST_CMD=split-window -h -t =dev:shell -c ~/projects
POST_CMD=select-window -t =dev:edit
```

A config can be as small as a single line — this starts session `minimal`
with one shell window in `$HOME` at boot:

```ini
# ~/.tmux-manager/minimal.conf
ENABLED=true
```

### Paired-pane layouts with join-pane

To build windows that combine several commands as panes, declare each pane
as its own window with a unique name, then merge them with `POST_CMD`
`join-pane` lines (a window disappears automatically once its last pane
moves out):

```ini
WINDOW=app1:./run-app
WINDOW=shell1
WINDOW=app2:./run-app
WINDOW=shell2

# Each app window gets its shell on the right
POST_CMD=join-pane -h -s =myproj:shell1 -t =myproj:app1
POST_CMD=join-pane -h -s =myproj:shell2 -t =myproj:app2
# Close the index gaps left by the consumed windows
POST_CMD=move-window -r -t =myproj
```

## CLI reference

```
tmux-manager list               table of sessions: enabled / running
tmux-manager enable <session>   start at boot (sets ENABLED=true in the conf)
tmux-manager disable <session>  don't start at boot (sets ENABLED=false)
tmux-manager start <session>    start now (regardless of ENABLED)
tmux-manager stop <session>     kill a managed session
tmux-manager attach <session>   attach (or switch-client when inside tmux)
tmux-manager rename <old> <new> rename conf file, POST_CMD references,
                                and the running session if there is one
tmux-manager sessions           plain list of configured names (scripting)
tmux-manager boot               used by the unit: start all enabled sessions
tmux-manager shutdown           used by the unit: kill all managed sessions
```

`stop` and `shutdown` only ever touch sessions defined by a conf file —
your manually created sessions are never killed by the CLI.

The config directory can be overridden with `TMUX_MANAGER_CONF_DIR`
(useful for testing).

## Systemd notes

```sh
sudo systemctl enable --now tmux-manager@alice   # per user, as root
systemctl status tmux-manager@alice
journalctl -u tmux-manager@alice
```

- **Boot behavior:** a missing config directory, no configs, or no enabled
  sessions is success ("nothing to do"). One broken config among working
  ones logs a warning and continues. The unit only fails if *every* enabled
  session failed to start.
- **`systemctl stop` caveat:** `ExecStop` kills the managed sessions and
  leaves the server alone if unmanaged sessions remain — but if the unit
  itself spawned the tmux server, systemd's cgroup cleanup then terminates
  that server, taking any manually added sessions with it. Use
  `tmux-manager stop <session>` for surgical stops. (Sessions created
  before the unit started live outside its cgroup and are never affected.)
- **Crash visibility:** with `Type=oneshot` the unit stays `active (exited)`
  even if the tmux server later dies; `tmux-manager list` is the source of
  truth for what is actually running.

### Persistence across logout

tmux sessions die at logout when two things line up: the tmux server is running
inside your SSH login's systemd scope (`session-<n>.scope`), and logind is set
to `KillUserProcesses=yes` (it SIGKILLs everything in a session's scope when the
session ends). tmux-manager avoids this by making sure the server is never born
in a login scope:

- **Started at boot (the unit):** the server runs in the unit's own
  `system.slice` cgroup, independent of any login. It survives every logout and
  lasts until shutdown — no lingering required.
- **Started by hand (`tmux-manager start`, when no server is running yet):**
  the CLI launches it via `systemd-run --user --scope`, parking the server
  under `user@<uid>.service` instead of the ephemeral login scope. With
  **lingering enabled** that cgroup outlives every login, so the session
  survives logout even under `KillUserProcesses=yes`.

For hand-started sessions, enable lingering once:

```sh
sudo loginctl enable-linger <user>
```

- A plain `tmux` (not via tmux-manager) started from a login shell still lands
  in the login scope and dies at logout under `KillUserProcesses=yes`. Start via
  `tmux-manager start`, or let the boot unit own the server, for durable
  placement.
- If you `enable` a session *after* boot and want it persistent immediately,
  either `tmux-manager start` it (user-scope placement) or
  `sudo systemctl restart tmux-manager@<user>` so the unit re-owns the server in
  `system.slice`. Whichever path first creates the server fixes its cgroup;
  every later session shares that one server.

## Uninstall

```sh
sudo systemctl disable --now 'tmux-manager@*'
sudo rm /etc/systemd/system/tmux-manager@.service \
        /usr/local/bin/tmux-manager \
        /usr/share/bash-completion/completions/tmux-manager
sudo rm -rf /opt/tmux-manager
sudo systemctl daemon-reload
```

Per-user configs in `~/.tmux-manager/` are yours to keep or delete.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Everett C. Haimes III.
