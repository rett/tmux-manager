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
