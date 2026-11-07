# Architecture

`vps-guard.sh` is the entry point. It parses the command, loads modules, and either runs the audit or opens the menu.

## Layout

```text
vps-guard.sh              entry point and command dispatch
install.sh                standalone installer; does not load lib/
VERSION                   release version
lib/
  common.sh               small shared helpers and path overrides
  i18n.sh                 message catalog
  ssh.sh                  SSH config backup, validation, reload, port helpers
  ssh_port.sh             keep-22 port change transaction
  ssh_shortcut.sh         20001 shortcut transaction
  keys.sh                 authorized_keys writing
  net.sh                  IPv6 and listening-port parsing
  fail2ban.sh             Fail2Ban status parsing
  ufw.sh                  UFW default-policy rollback
modules/
  audit/                  read-only checks, grouped by topic
  harden/ssh.sh           root password hardening
  ui/                     interactive menus, grouped by feature
tests/
  run.sh                  test runner
  lib.sh                  assertions and temporary directories
  mocks/                  ufw, systemctl, sshd and ss stubs
```

`modules/menu.sh` is a compatibility loader for `modules/ui/*.sh`. New menu code belongs in `modules/ui/`, not in the loader.

## Load order

The entry point loads `i18n.sh`, `common.sh`, the shared libraries, the audit modules, the hardening module, and finally the UI loader. Function definitions may reference functions loaded later because calls happen after all files are sourced.

## Naming

- `audit_*`: read-only inspection.
- `harden_*`: system-changing SSH hardening.
- `ui_*`: interactive input and output.
- `ssh_*`, `tcp_*`, `ufw_*`, `fail2ban_*`: shared helpers in `lib/`.

Keep system-changing logic in `lib/` so it can be tested without a menu. `lib/ssh_port.sh` and `lib/ssh_shortcut.sh` return a result in `SSH_CHANGE_RESULT`; the UI layer only prompts, calls them, and maps the result to text.

## Path overrides

Tests set these variables; production defaults remain the standard paths:

```bash
VPS_GUARD_SSH_DIR=/etc/ssh
VPS_GUARD_SYSTEMD_DIR=/etc/systemd/system
VPS_GUARD_UFW_DEFAULTS=/etc/default/ufw
VPS_GUARD_ROOT_AUTHORIZED_KEYS=/root/.ssh/authorized_keys
VPS_GUARD_SSH_BACKUP_DIR=/var/backups/vps-guard
```

`ssh_config_backup` writes a timestamped copy under `VPS_GUARD_SSH_BACKUP_DIR` in addition to the temporary rollback copy. Tests point it at a temporary directory.

## Adding a menu item

1. Add the implementation to the relevant `lib/` module or an existing `modules/ui/` file.
2. Add the menu label to `ui_main_menu` in `modules/ui/main.sh`.
3. Add a test under `tests/` using a mock if the path changes the system.
4. Run `make check`.
