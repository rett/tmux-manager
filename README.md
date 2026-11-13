# tmux-manager

tmux-manager manages configured tmux sessions with systemd user services. A
persistent server service owns the normal default socket, so `tmux ls` and
plain tmux clients can see the sessions. Each session has its own service:
restarting one does not restart the server or other sessions. The server stays
alive after the last session is stopped.

## Requirements and installation

Linux with systemd user services, lingering, Bash, and tmux with the `-N`
option are required. Install with `./scripts/install.sh`. The installer places
the CLI and support library in `/opt/tmux-manager`, user units in
`/etc/systemd/user`, the compatibility system unit in `/etc/systemd/system`,
and completion in `/usr/share/bash-completion/completions`. It reloads the
system manager but does not restart or stop services.

For each user, enable lingering (an administrator action) and start the boot
service:

```sh
sudo loginctl enable-linger <user>
systemctl --user daemon-reload
systemctl --user enable --now tmux-manager.service
```

Create `~/.tmux-manager/dev.conf` and run `tmux-manager start dev`, then
`tmux-manager attach dev`. Public startup requires lingering and a reachable
user manager; it fails if either is unavailable. A server already running
outside the server service is refused and left untouched. Session processes
belong to the server's persistent cgroup and survive logout while the user
manager remains running.

## Migration from the system template

The old `tmux-manager@<user>.service` may own the existing server and its
unmanaged sessions. Plan downtime and save or finish all valuable sessions
before stopping anything. Disable the old system unit without stopping it,
then, only after the sessions can be discarded, stop it and confirm that the
default server is gone. Enable lingering and the user service as above. Do not
try to adopt or kill a foreign server to force startup. The retained system
template forwards boot and shutdown to the user manager for compatibility; do
not enable both boot services. Check `systemctl --user status
tmux-manager-server.service` and the journal if startup fails.

## Configuration

Each `~/.tmux-manager/<file>.conf` contains literal `KEY=VALUE` lines and
full-line comments. A config may specify:

| Key | Meaning |
| --- | --- |
| `SESSION_NAME` | Session name, defaulting to the filename; letters, digits, `_`, `@`, `-` |
| `START_DIR` | Working directory, default `$HOME`; `~` and `$HOME` expand |
| `ENABLED` | `true` starts at boot; default `false` |
| `WINDOW` | Repeatable `name:command`, or `name` for a shell |
| `POST_CMD` | Repeatable raw tmux command after creation |

```ini
SESSION_NAME=dev
START_DIR=~/projects
ENABLED=true
WINDOW=edit:vim .
WINDOW=shell
POST_CMD=split-window -h -t =dev:shell
```

Commands are typed literally into shells; the shell remains after a command
exits. Use exact targets such as `=dev` in post commands. Explicit `start`
works even when `ENABLED=false`; `enable` and `disable` change boot behavior.
The boot service continues past individual failures and fails when all enabled
sessions fail. Shutdown reports any failed unit stop.

`TMUX_MANAGER_CONF_DIR` overrides the configuration directory. User services
inherit the systemd user manager environment, not the calling shell. Set the
same value there (for example, `systemctl --user set-environment
TMUX_MANAGER_CONF_DIR=/absolute/path`) and in the shell before invoking the
CLI. A mismatch fails clearly. The same rule applies to `TMUX_TMPDIR` and the
unit prefix used by isolated tests. Changes to manager environment affect
future services; arrange their persistence separately if needed at boot.

## Commands

`list` shows configured sessions; `sessions` prints names for scripts.
`enable NAME` and `disable NAME` set boot behavior. `start NAME`, `stop NAME`,
and `restart NAME` operate on the corresponding user unit. `attach NAME`
switches clients when already inside the default server and otherwise attaches
to that server. `rename OLD NEW` updates the configuration and exact target
references; stop the session first. `boot` and `shutdown` start enabled and
stop configured session units respectively. Unconfigured sessions are not
targeted by these commands. Directly killing a session leaves its oneshot unit
active; a subsequent `start` repairs it.

`service status|start|stop|restart|enable|disable boot|server` controls the
named user unit. Stopping or restarting the server affects every session it
owns; the boot unit starts or stops configured sessions. `service status
session NAME` inspects one session unit. Status accepts `--json` for scripts.
`sessions --json` prints an array of configured names. Commands return zero on
success and nonzero on errors; diagnostics go to standard error.

### Optional unattended persistence setup

`tmux-manager sudoers preview` prints the exact rule for the invoking user;
`tmux-manager sudoers check` checks whether sudo currently permits that command.
Installation is optional and needs a one-time administrator action after the
normal installation: `sudo /opt/tmux-manager/sbin/tmux-manager-sudoers install`.
The main CLI provides `sudoers install` and `sudoers remove` actions using
noninteractive sudo. These require existing administrator authorization; if it
is unavailable, run the displayed administrator command directly. They never
grant permission to run the installer. The helper validates the rule with visudo and
refuses to overwrite or remove a different or unsafe file. Removal uses the
same command with `remove`. The rule grants only `/usr/bin/loginctl
enable-linger` for the invoking user; user service control requires no root.
Once authorized, `tmux-manager service setup` uses noninteractive sudo to enable
linger, reloads the user manager and enables and starts the boot service. That
service starts all enabled configured sessions. Failed authorization returns an
error without prompting. The initial administrator action may prompt normally.

## Development and tests

Run `make doctor` then `bash tests/run.sh`. The lifecycle test uses a private
socket. `TMUX_MANAGER_LIVE_TEST=1 bash tests/live-systemd.sh` is an opt-in
integration test requiring an existing user bus; it uses unique runtime units,
a private socket, and a test-only linger response. Never point
tests at an existing server. See [AGENTS.md](AGENTS.md) for setup.

## Uninstall

After saving sessions, disable and stop the user service and server explicitly,
then remove the installed files and reload the relevant systemd managers.
Configuration files remain in `~/.tmux-manager` until removed separately.

## License

MIT — see [LICENSE](LICENSE).
# Installation safety

The installer requires root-owned, non-group/world-writable directories under
`/opt/tmux-manager` and rejects symlinked installations. During a coordinated
migration, preserve the existing checkout and sessions, remove the old link
only after arranging downtime, and install into a trusted root-owned directory.

Service mutations require the invoking environment to match the user manager;
starting or restarting services also requires lingering to be enabled.
Environment values reported with systemd ANSI-C quoting are supported.

Development bootstrap supports apt-get and pacman; `make -n bootstrap` previews
the required package installation without upgrading the system.

