# VPS Guard

[中文](README.md) | **English**

A basic inspection and management tool for Ubuntu/Debian VPS instances. This guide explains what each menu item is for, what it reads or changes, and what to consider before using it—not just what the labels say. Read-only checks do not change the system. Actions that change system state generally show their target and require `y` to confirm or `n` to cancel (case-insensitive).

## Menu-to-script map

| Main menu option | Script action | Type |
| --- | --- | --- |
| 1 Information audit | `audit_all`: system, SSH, network/firewall/listeners, services, users, Docker, resources, baseline checks, and the tail of an APT `full-upgrade` simulation | Read-only |
| 2 SSH / firewall | Opens SSH/firewall submenu: status, port/socket, port-20001 shortcut, UFW rules | Inspect/configure |
| 3 IPv6 | Shows interface/sysctl/UFW IPv6 status; sub-option 1 enables it | Inspect/configure |
| 4 BBR / fq | Shows active/available algorithms and queue discipline; sub-option 1 enables them | Inspect/configure |
| 5 Updates | Simulates `apt-get upgrade`; `y` runs `apt-get update` and `apt-get upgrade -y` | Update |
| 6 Services | Lists 9 fixed services and lets you inspect/start/stop/restart/reload the selection | Inspect/control |
| 7 Listening ports | Runs `ss -H -tulpen` and labels all-address, loopback, or specific-address binds | Read-only |
| 8 Fail2Ban | Shows jail/ban IPs, unbans an IP, or displays logs | Inspect/configure |
| 9 Users/keys | Lists users/sudo, creates a user, adds a key, or disables root password authentication | Inspect/configure |
| 10 Resources | Shows load, memory, disk, inodes, and CPU/memory-heavy processes | Read-only |
| 11 Logs | SSH, Fail2Ban, UFW-related denied kernel messages, and error-priority logs | Read-only |
| 12 Docker | Lists/controls containers, tails logs, and tests Nginx config before an explicitly confirmed reload | Inspect/control |
| 13 Scheduled tasks | Lists timers and views/adds/deletes root crontab lines | Inspect/configure |
| 14 Cleanup | APT cache, systemd journal, stopped containers, dangling images | Cleanup |
| 15 Network check | Addresses, routes, DNS, public IPv4/IPv6 lookup | Read-only |
| 16 Export status | Prints SSH/network audits, Fail2Ban status, and running Docker summary to the terminal | Read-only output |
| 17 Extended diagnostics | Largest directories, failed units/reboot status, HTTP/TLS, bounded route trace | Read-only/optional network requests |

The sections below expand the exact actions in each submenu. Main menu option `0` exits.

## Menu guide

See [docs/menu.en.md](docs/menu.en.md) for the actions, files touched, and risks of each menu item.

## Project structure and development

- `vps-guard.sh`: entry point, argument dispatch, and module loading.
- `lib/`: shared SSH, key, network, UFW, and Fail2Ban helpers.
- `modules/audit/`: read-only checks; `modules/harden/`: hardening; `modules/ui/`: interactive menus.
- `tests/`: regression tests, command mocks, and the test runner.

See [docs/architecture.md](docs/architecture.md), [docs/testing.md](docs/testing.md), and [docs/recovery.md](docs/recovery.md) for structure, tests, and SSH/firewall recovery. Version and changes are in `VERSION` and `CHANGELOG.md`; security reporting is in `SECURITY.md`.

```bash
make check    # syntax + regression tests
make lint     # requires shellcheck
```

## Run

Run the interactive menu from the project directory:

```bash
sudo bash vps-guard.sh ui
```

Run a command-line audit (Chinese by default, or English) and recommendations:

```bash
sudo bash vps-guard.sh audit
sudo bash vps-guard.sh audit en
sudo bash vps-guard.sh plan
```

Exiting the menu after installation does not remove the program. Run it again with:

```bash
sudo bash /opt/vps-guard/vps-guard.sh ui
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CharlesField19/vps-guard/main/install.sh | sudo bash
```

The default installation path is `/opt/vps-guard`, and the menu opens after installation. Running the installer again backs up the existing directory to `/var/backups/vps-guard/<timestamp>` before replacing it. The installer rejects `/`, `/opt`, `/etc`, system bin/log directories, `/tmp`, and similar unsafe paths. Set `VPS_GUARD_SHA256=<sha256>` to verify the downloaded archive with `sha256sum -c`. Set `VPS_GUARD_NO_UI=1` for an automated install that does not open the menu.

## General notes

- Root access is required. Ubuntu/Debian systems using APT are the primary target. Some features require the relevant software/commands to be installed (for example UFW, Fail2Ban, Docker, or systemd).
- Start with the information audit. For any action that changes system state, enter `y` (case-insensitive) to confirm; enter `n` or anything else to cancel.
- SSH, firewall, and network changes may disconnect remote access. Ensure a VPS console or rescue path is available first. After changing the SSH port, test login from a second terminal before manually considering removal of the old port rule.
- Changing the SSH port, disabling root password login, and the port-20001 shortcut roll back that SSH change if validation or reload fails. The shortcut also restores UFW defaults if changing them fails. Other updates, cleanup, and account actions still have no automatic rollback. Make your own backups of important data and configuration.
- Updates do not reboot automatically. After updating, check whether the system requires a reboot.
