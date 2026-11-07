# Changelog

## 0.2.0 - 2026-11-07

- Split menu functions into `modules/ui/*.sh` and shared helpers into `lib/*.sh`.
- Moved the SSH port-change and 20001 shortcut transactions into `lib/ssh_port.sh` and `lib/ssh_shortcut.sh`; the UI only prompts and maps results.
- Added mock-based tests for SSH port changes, SSH hardening, and UFW paths, plus a test runner.
- Added path overrides for SSH, systemd, UFW, and root key locations so tests do not touch the host.
- SSH configuration changes keep a timestamped copy under `/var/backups/vps-guard` in addition to the temporary rollback copy.
- SSH port changes keep port 22, validate both ports, and roll back on failure.
- SSH socket drop-ins only bind IPv6 when IPv6 is available.
- Adding an SSH key refuses `.ssh`/`authorized_keys` symlinks and writes atomically.
- The 20001 shortcut allows the current port first and changes UFW defaults only after port 20001 listens.
- Hardening removes `PermitRootLogin` from drop-ins and restores files on validation failure; it accepts OpenSSH's `without-password` alias for `prohibit-password`.
- Fixed Fail2Ban jail parsing, shortcut package branching, listening-port detection, and Docker log line scoping.
- Installer rejects unsafe paths, backs up an existing install, checks a single archive root, and supports `VPS_GUARD_SHA256`.
- Avoided the gettext `LANGUAGE` variable; UFW policy parsing is pinned to `LC_ALL=C`.
- Added syntax, lint, and test targets plus CI configuration.

## 0.1.0

- Initial menu-based VPS audit and hardening tool.
