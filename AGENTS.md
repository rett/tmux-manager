# tmuxmanager

## Development environment

This project has no tool-specific setup file. The targets below are the specification; any agent or person sets a checkout up with them.

- Prerequisites: bash, git, make, tmux (with `-N` support), ShellCheck, and systemd user tools (`systemctl`, `systemd-escape`, `loginctl`).
- Install or update everything: `make bootstrap`. It is idempotent. A line that needs root starts with `sudo` and says what it changes. Preview without changes: `make -n bootstrap`.
- Verify a checkout: `make doctor`. It prints one line per item and exits non-zero when something is missing: a line starting `missing`, `fail` or `error` is a problem, a line starting `expected` is a known failure that is accepted. Run it before the tests and after pulling.
- Tests: `bash tests/run.sh`.
- Never run the bootstrap on a checkout you have not reviewed; read the preview first.
- When the project needs a new tool, add it to the bootstrap, to the doctor and to this list in the same change.
