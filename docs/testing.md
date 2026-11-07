# Testing

## Commands

```bash
make syntax   # bash -n for every shell file
make test     # tests/run.sh
make lint     # shellcheck, requires shellcheck
make check    # syntax + test
```

`tests/run.sh` runs `tests/regression.sh` and every `tests/test_*.sh`. Each file runs in its own shell process, so environment changes do not leak between tests.

## Test environment

- `tests/test_firewall.sh`, `tests/test_ssh.sh`, and `tests/test_ssh_port.sh` skip unless run as root.
- `tests/test_ssh.sh` skips unless `sshd` is installed.
- `tests/mocks/` contains `ufw`, `systemctl`, `sshd`, and `ss` stubs. Tests prepend this directory to `PATH` and set `MOCK_LOG` to record calls.
- Files under test use `VPS_GUARD_SSH_DIR`, `VPS_GUARD_SSH_BACKUP_DIR`, and related variables, so tests write to temporary directories rather than `/etc` or `/var/backups`.
- Tests do not reload SSH, restart `ssh.socket`, enable UFW, or write host configuration. The only real command used against the host is read-only `sshd -T` validation of a temporary config.

The SSH port-change and 20001 shortcut transactions return their outcome in `SSH_CHANGE_RESULT`, so the same paths can be tested without driving the interactive menu.

## What is covered

- Fail2Ban tree output parsing.
- `ss` output parsing without treating Send-Q as a port.
- Effective SSH port validation.
- Installer path rejection.
- SSH config backup/restore and keeping port 22.
- Non-socket and socket SSH port changes, including socket restart failure and rollback.
- Root password hardening success and byte-for-byte restore on failure.
- `authorized_keys` symlink refusal and atomic write.
- UFW allow/reload/default-deny ordering and policy rollback.

## What still needs a disposable VM

Real `systemctl reload ssh`, `systemctl restart ssh.socket`, `ufw` enable/disable, and cloud security-group behavior are not exercised in CI. Use a throwaway VM and a second SSH session for those paths.
