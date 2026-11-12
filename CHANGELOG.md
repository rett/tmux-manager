# Changelog

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Development
- Add bootstrap, environment diagnostics and static checks to CI.

### Changed
- A persistent user service owns the default tmux server; per-session user
  units allow independent start, stop and restart. Startup requires lingering
  and refuses existing foreign servers. See the migration instructions.
- Configuration overrides must match the systemd user manager environment.
- Renaming a running managed session requires stopping it first.
- Add explicit user-service control and machine-readable service status.
- Add JSON session names, persistence setup and an optional exact linger sudoers
  rule with a separate administrator installer; fix attachment outside tmux.
- Make sudoers install and remove available through noninteractive CLI actions.
# Unreleased

- Resolve installed command symlinks and reject untrusted installation paths.
- Check manager settings before service mutations and enforce persistence for starts.
- Decode systemd ANSI-C quoted environment values without evaluating them.
- Bootstrap prerequisites with apt-get or pacman, without upgrading the system.
