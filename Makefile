SHELL := /bin/bash
FILES := vps-guard.sh install.sh lib/*.sh modules/audit/*.sh modules/harden/*.sh modules/menu.sh modules/ui/*.sh tests/*.sh tests/mocks/*

.PHONY: syntax test lint check

syntax:
	@for f in $(FILES); do bash -n "$$f" || exit 1; done
	@echo 'syntax: OK'

test:
	@bash tests/run.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo 'shellcheck is not installed'; exit 1; }
	shellcheck -x -S error $(FILES)

check: syntax test
