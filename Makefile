.PHONY: bootstrap doctor

# Debian/Ubuntu packages; installation requires administrator privileges.
bootstrap:
	sudo apt-get update
	sudo apt-get install -y bash git make tmux shellcheck systemd

doctor:
	@failed=0; for tool in bash git make tmux shellcheck systemctl systemd-escape loginctl; do \
	  if command -v "$$tool" >/dev/null 2>&1; then \
	    if [ "$$tool" = tmux ]; then version=$$(tmux -V); else version=$$("$$tool" --version 2>&1 | head -n 1); fi; \
	    printf 'ok: %s %s\n' "$$tool" "$$version"; \
	  else printf 'missing: %s\n' "$$tool"; failed=1; fi; \
	done; \
	if tmux -h 2>&1 | head -n 1 | grep -qE '\[-[^]]*N'; then printf 'ok: tmux supports -N\n'; else printf 'fail: tmux lacks -N\n'; failed=1; fi; \
	if bash -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))'; then printf 'ok: bash >= 4.4\n'; else printf 'fail: bash >= 4.4 required\n'; failed=1; fi; \
	exit $$failed
