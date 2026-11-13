.PHONY: bootstrap doctor

# Installation requires administrator privileges. No system upgrade is run.
PACKAGE_MANAGER := $(shell if command -v apt-get >/dev/null 2>&1; then printf apt; elif command -v pacman >/dev/null 2>&1; then printf pacman; else printf unsupported; fi)

bootstrap:
ifeq ($(PACKAGE_MANAGER),apt)
	sudo apt-get install -y bash git make tmux shellcheck systemd sudo
else ifeq ($(PACKAGE_MANAGER),pacman)
	sudo pacman -S --needed --noconfirm bash git make tmux shellcheck systemd sudo
else
	@printf '%s\n' 'unsupported: install prerequisites with apt-get or pacman' >&2; exit 1
endif

doctor:
	@failed=0; for tool in bash git make tmux shellcheck systemctl systemd-escape loginctl sudo visudo; do \
	  if command -v "$$tool" >/dev/null 2>&1; then \
	    if [ "$$tool" = tmux ]; then version=$$(tmux -V); else version=$$("$$tool" --version 2>&1 | head -n 1); fi; \
	    printf 'ok: %s %s\n' "$$tool" "$$version"; \
	  else printf 'missing: %s\n' "$$tool"; failed=1; fi; \
	done; \
	if tmux -h 2>&1 | grep -qE '\[-[^]]*N'; then printf 'ok: tmux supports -N\n'; else printf 'fail: tmux lacks -N\n'; failed=1; fi; \
	if bash -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))'; then printf 'ok: bash >= 4.4\n'; else printf 'fail: bash >= 4.4 required\n'; failed=1; fi; \
	exit $$failed
