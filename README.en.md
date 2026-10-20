# VPS Guard

[中文](README.md) | **English**

A basic inspection and management tool for Ubuntu/Debian VPS instances. This guide explains what each menu item is for, what it reads or changes, and what to consider before using it—not just what the labels say. Read-only checks do not change the system. Actions that change system state generally show their target and require you to type `APPLY`.

## Menu-to-script map

| Main menu option | Script action | Type |
| --- | --- | --- |
| 1 Information audit | `audit_all`: system, SSH, network/firewall/listeners, services, users, Docker, resources, baseline checks, and the tail of an APT `full-upgrade` simulation | Read-only |
| 2 SSH / firewall | Opens SSH/firewall submenu: status, port/socket, port-20001 shortcut, UFW rules | Inspect/configure |
| 3 IPv6 | Shows interface/sysctl/UFW IPv6 status; sub-option 1 enables it | Inspect/configure |
| 4 BBR / fq | Shows active/available algorithms and queue discipline; sub-option 1 enables them | Inspect/configure |
| 5 Updates | Simulates `apt-get upgrade`; `APPLY` runs `apt-get update` and `apt-get upgrade -y` | Update |
| 6 Services | Lists 9 fixed services and lets you inspect/start/stop/restart/reload the selection | Inspect/control |
| 7 Listening ports | Runs `ss -H -tulpen` and labels all-address, loopback, or specific-address binds | Read-only |
| 8 Fail2Ban | Shows jail/ban IPs, unbans an IP, or displays logs | Inspect/configure |
| 9 Users/keys | Lists users/sudo, creates a user, adds a key, or disables root password authentication | Inspect/configure |
| 10 Resources | Shows load, memory, disk, inodes, and CPU/memory-heavy processes | Read-only |
| 11 Logs | SSH, Fail2Ban, UFW-related denied kernel messages, and error-priority logs | Read-only |
| 12 Docker | Lists containers and starts/stops/restarts the selected one | Inspect/control |
| 13 Scheduled tasks | Lists timers and views/adds/deletes root crontab lines | Inspect/configure |
| 14 Cleanup | APT cache, systemd journal, stopped containers, dangling images | Cleanup |
| 15 Network check | Addresses, routes, DNS, public IPv4/IPv6 lookup | Read-only |
| 16 Export status | Prints SSH/network audits, Fail2Ban status, and running Docker summary to the terminal | Read-only output |

The sections below expand the exact actions in each submenu. Main menu option `0` exits.

## Menu guide

### 1. VPS information audit (read-only)

Collects a high-level snapshot of the server. Use it when taking over a VPS, gathering facts before troubleshooting, or sharing system context with an administrator. It covers distribution/kernel, uptime, memory, disk space, SSH configuration, firewall state, listening ports, login records, common services, Docker, and an update simulation. This is an inventory, not an automatic repair tool or a complete security scanner; interpret services, ports, and update information in the context of what the server is intended to do.

Exact output groups: system information (distribution, kernel, uptime, execution identity, UTC time); SSH effective settings, authorized-key files/permissions, and selected risk notices; UFW plus firewalld/nftables when available and listening ports; status of Fail2Ban, auditd, AppArmor, UFW, and Docker plus an attempt to query the SSH jail; UID 0 accounts, sudo/adm groups, recent successful/failed logins and recent successful SSH authentication; running Docker containers, images/ports/status, and privileged/network/PID/mount settings; root disk, memory, swap, selected sysctl values, sensitive-file permissions, pending reboot marker and UMASK; finally, when APT is present, the last 8 lines of an `apt-get -s full-upgrade` simulation. This entry does not apply updates or automatically fix findings.

### 2. SSH / firewall

The entry point for remote SSH access and the UFW host firewall. They are managed together because the SSH daemon must listen on a port and the firewall must allow traffic to that port; changing only one side may prevent connections.

- **View current status**: Runs SSH and network audits without changing anything.
- **SSH port and socket management**: Shows the effective `sshd` port, `ssh.socket` listener settings, and actual TCP listeners. This avoids assuming that a configured port is already active. When setting a port, it first attempts to allow the new TCP port and retains port 22 for testing; it does not automatically close the old port. Some distributions use systemd socket activation, where `ssh.socket` owns the listener, so that unit must be considered too. Verify login on the new port from a second terminal before deciding whether to remove old firewall rules.
- **Apply SSH 20001 + basic firewall rules**: A preset that configures SSH TCP port `20001`, allows `20001/80/443`, sets UFW's default incoming policy to deny and outgoing policy to allow, and enables UFW. Use it only when this policy matches your setup; it is not a universal one-click security configuration. Any service using another port must be allowed separately. The action does not automatically back up or roll back changes.
- **Manage UFW rules**: Adds allow rules for TCP, UDP, or both; lists and deletes rules by number; enables/disables UFW; and sets default incoming/outgoing policies.
  - “Incoming” means connections arriving at the VPS. A default deny policy generally allows only traffic covered by explicit rules.
  - “Outgoing” means connections initiated by the VPS. Default deny can disrupt DNS, package updates, API calls, and other outbound traffic.
  - Allowing a port only permits traffic through the firewall; it does not start the application that should receive it. Disabling the firewall or allowing incoming traffic by default may expose services. Removing an SSH rule may disconnect your current session. Check the SSH port and ensure you have a provider console/rescue path before changing policies.

UFW submenu numbering: 1 add a port rule (then choose TCP, UDP, or both); 2 list numbered rules and delete a selected number; 3 enable UFW; 4 disable UFW; 5 default incoming deny; 6 default incoming allow; 7 default outgoing allow; 8 default outgoing deny; 0 back. Options 4, 6, and 8 show a high-risk warning.

The SSH-port submenu has two options: 1 enter a new port from `1-65535`, allow it, retain port 22, then write the relevant socket drop-in or `sshd_config`, validate the configuration, and reload/restart the service; 0 back. If an unmanaged custom socket drop-in is detected, the script does not overwrite it. The shortcut is option 3 of the SSH/firewall submenu, not an option inside the port submenu.

### 3. IPv6 status and configuration

Displays IPv6 interface records, the kernel's IPv6 disable switches, and UFW's IPv6 setting. Enabling IPv6 writes `/etc/sysctl.d/99-vps-guard-ipv6.conf`, enables IPv6 on the VPS, and sets `IPV6=yes` when a UFW configuration is present. This only changes the guest system; it cannot provision IPv6 with your cloud provider. The provider must assign IPv6 addressing/routing, and its security group must also permit the desired traffic. Seeing an interface record does not guarantee public IPv6 connectivity.

The menu repeatedly shows the status; option 1 enables IPv6 and requires `APPLY`, while 0 returns. The script runs `sysctl --system` and checks that `net.ipv6.conf.all.disable_ipv6=0`; if validation fails, written files remain and no automatic rollback occurs.

### 4. BBR / fq status and configuration

Shows the active TCP congestion-control algorithm, algorithms reported by the kernel, and the default queue discipline. BBR is a Linux TCP congestion-control algorithm; `fq` is a packet queueing discipline commonly paired with it. They change TCP traffic handling, not your provisioned bandwidth, and will not fix every network issue. Enabling first checks that the kernel reports BBR support, then writes `/etc/sysctl.d/99-vps-guard-network.conf` and applies the settings immediately. If the kernel does not support BBR or validation fails, the configuration is not automatically rolled back; inspect the reported file and kernel support.

Option 1 first checks that `bbr` appears among the available algorithms, then requires `APPLY`. Success is verified by checking that the active congestion control is `bbr` and the default queue is `fq`. Option 0 returns; no configuration is written when BBR is unavailable.

### 5. Software and kernel updates

For Ubuntu/Debian systems using APT. It first simulates `apt-get upgrade` using the local package index so you can review the expected package changes; the simulation neither accesses the network nor installs software. Only after you type `APPLY` does it run `apt-get update` to refresh package indexes and `apt-get upgrade -y` to install available upgrades. It does not run `full-upgrade`, which may remove packages, and it does not reboot automatically. A kernel update may require a manual reboot during a maintenance window. Keep the terminal and network connection available while updates run.

This is a single update flow rather than a looping submenu: type `APPLY` after the preview to run it, `0` to return, or anything else to cancel as an invalid choice. If `apt-get` or `apt-cache` is unavailable, it stops. After a successful update, the script checks `/var/run/reboot-required` and reports when a reboot is needed.

### 6. Service management

Lists the active state of common systemd units—SSH, `ssh.socket`, UFW, Fail2Ban, Docker, Nginx, Cron, AppArmor, and auditd—and lets you inspect details or start, stop, restart, or reload a service.

- **Start**: Starts a service that is not running.
- **Stop**: Interrupts a service. Stopping SSH may disconnect remote administration; stopping UFW changes firewall protection.
- **Restart**: Stops and starts the service, potentially causing a brief outage.
- **Reload**: Asks a service to reread its configuration, usually without stopping the process. The action fails if the service does not support reload.

This is not a browser for every installed service; only common units listed in the script are shown. Check the selected service and its impact before applying an action.

### 7. Listening port inspection

Uses `ss` to show current TCP/UDP listeners, including IPv4/IPv6, bind address, port, and process details. `127.0.0.1`/`::1` usually means local loopback access only. `0.0.0.0`, `[::]`, or a wildcard address means listening on all corresponding local addresses and may make a service reachable publicly. Actual reachability also depends on UFW, cloud security groups, routing, and application authentication. This check reports listeners; it does not change ports or stop services.

### 8. Fail2Ban management

Fail2Ban uses jails—rules watching a particular service or log source—to ban source IPs after repeated failures. The menu shows jail and ban status, displays a jail's status and banned IPs, unbans an IP from a selected jail, and shows Fail2Ban logs. Unbanning lets the IP try to connect again; verify both the jail and IP before typing `APPLY`. Logs may contain IP addresses and usernames.

Submenu numbering: 1 select a jail and display its status/banned IPs; 2 select a jail, enter an IP, and confirm the unban; 3 display the latest 80 Fail2Ban journal lines; 0 back. If the client is missing or the service cannot be reached, this feature reports that and returns.

### 9. Users and SSH keys

- **List users and sudo group**: Shows accounts with login-capable shells and members of the sudo group. This helps identify accounts that may log in or obtain administrator privileges. It does not show passwords or modify accounts.
- **Create a regular user**: Creates a local account with a home directory and the default Bash shell, optionally adding it to the sudo group. Sudo membership usually grants administrative access. This action does not set a password; configure login separately with `passwd` or an SSH public key.
- **Add an SSH public key**: Appends one supplied public-key line to the user's `~/.ssh/authorized_keys` and sets standard directory/file permissions. Verify that the key belongs to the intended user; existing keys are appended to, not replaced.
- **Enable root key login and disable root password login**: Requires root's `authorized_keys` file and asks you to confirm that the key has successfully logged in from a second SSH session. It sets `PermitRootLogin` to `prohibit-password` and attempts to reload SSH. Root password authentication is disabled, while root public-key login remains allowed. Keep the verified session open and ensure a console/rescue path is available. The tool does not automatically back up or roll back the configuration.

Submenu numbering: 1 list users and sudo group; 2 create a regular user and choose whether to add it to sudo; 3 append one public-key line for a selected user; 4 harden root password login; 0 back.

### 10. Resource monitoring (read-only)

Shows system load, RAM use, filesystem space, inode use, and processes ranked by CPU and memory consumption. Load is a recent average of runnable/waiting work, not a CPU percentage. A filesystem may have free space but still fail to create files if it has run out of inodes. This view only reports data; it does not terminate processes or clean disks.

### 11. Log viewer (read-only)

Displays recent systemd journal entries: SSH/sshd service logs, Fail2Ban logs, kernel messages matching UFW/BLOCK/DENY, or service messages at error through alert priority. The default is 80 recent lines, capped at 500; no report file is written. Logs help investigate failed logins, bans, and service errors, but may contain IP addresses, usernames, or other sensitive data. Review and redact them before sharing.

Number mapping: 1 SSH service logs; 2 Fail2Ban service logs; 3 kernel messages containing UFW/BLOCK/DENY; 4 journal records at err through alert priority. Then enter the line count (default 80; values above 500 are capped); 0 returns.

### 12. Docker management

Shows all Docker containers, including stopped ones, with names, status, and port mappings. You can start, stop, or restart a selected container. A port mapping forwards a host port to a container port; a mapping bound to all addresses may be public, so also check the firewall and application authentication. Stop/restart interrupts the application. This menu does not edit container configuration, images, or volumes.

The list is shown first. Option 1 enters container controls; select a container, then choose 1 start, 2 stop, or 3 restart. After confirmation, only the selected container is affected. Option 0 returns to the previous menu.

### 13. Scheduled task management

The first section lists systemd timers read-only. The second section views and manages **the root user's own crontab**; it does not edit other users' jobs.

- **Add a Cron job**: Enter one complete line: five schedule fields (minute, hour, day of month, month, day of week), followed by a command. Example: `0 3 * * 0 /usr/local/sbin/backup.sh` runs the script every Sunday at 03:00. The tool performs only a basic completeness check; it does not validate that the command works or that the schedule is what you intended. Root Cron runs with administrative privileges, so an incorrect or overly frequent job can affect the system.
- **Delete a Cron job**: Select a line number from the current list to remove that one line from root's crontab. Check the displayed task to avoid deleting the wrong job.

Menu numbering: 1 add a Cron line; 2 delete the selected line; 0 back. The systemd timer section is list-only; it does not offer start/stop/edit actions.

### 14. Safe cleanup

Each cleanup shows its target or current usage first and requires `APPLY`. Cleanup cannot be automatically undone by this tool:

- **APT cache**: Removes downloaded package files to free disk space. Installed software is not uninstalled, but future installs/upgrades may need to download those files again.
- **Rotated systemd journals**: Reduces journal storage to the size limit you enter (for example, `200M`). Older records may be removed, limiting historical troubleshooting.
- **Stopped Docker containers**: Lists and removes exited/created but non-running containers. Data in a container's writable layer is lost; volumes and running containers are not targeted by this action.
- **Dangling Docker images**: Removes untagged image layers not referenced by containers; they can generally be pulled or built again if needed.

Confirm that the listed objects are safe to remove and that important data is backed up elsewhere.

The cleanup submenu numbers are the four actions above; after each action, press Enter to return to the cleanup menu. Journal cleanup accepts a number with an optional unit such as `200M` or `2G` and calls `journalctl --vacuum-size`; Docker cleanup lists the targets before calling the corresponding prune command.

### 15. Network security check (read-only)

Shows interface addresses, IPv4/IPv6 routes, DNS resolver configuration, and attempts to query public IPv4/IPv6 addresses through an external service. Public-IP lookup requires outbound internet access; a timeout may reflect network restrictions or an unavailable lookup service. This check does not change network settings and cannot inspect or change cloud security groups. Public access may also require rules in the provider console or network ACL.

Output order: interface addresses, IPv4/IPv6 routes, `resolvectl` (or `/etc/resolv.conf` if unavailable), public IPv4/IPv6 lookup, then a cloud-security-group reminder. This feature has no modification option.

### 16. Export configuration status to terminal

Prints SSH and network/UFW audit information, Fail2Ban status, and the status/ports of running Docker containers in sequence for copying into a troubleshooting conversation. This is not a file backup or a complete system export, and it does not upload data. Terminal output can still contain sensitive addresses or ports; review and redact it before sharing.

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

The default installation path is `/opt/vps-guard`, and the menu opens after installation. Running the installer again overwrites the existing installation; it does not create a backup of the installation directory.

## General notes

- Root access is required. Ubuntu/Debian systems using APT are the primary target. Some features require the relevant software/commands to be installed (for example UFW, Fail2Ban, Docker, or systemd).
- Start with the information audit. Any action that changes system state requires the confirmation word `APPLY`; other input does not confirm it.
- SSH, firewall, and network changes may disconnect remote access. Ensure a VPS console or rescue path is available first. After changing the SSH port, test login from a second terminal before manually considering removal of the old port rule.
- The script does not automatically back up or roll back configuration. Verify targets and impacts before updates, cleanup, or account changes; make your own backups of important data and configuration.
- Updates do not reboot automatically. After updating, check whether the system requires a reboot.
