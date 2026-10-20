# VPS Guard

[中文](README.md) | **English**

A basic inspection and management tool for Ubuntu/Debian VPS instances. The menu includes read-only checks and system changes that require confirmation.

## Features

1. **VPS information audit**: Summarizes system, CPU, memory, disk, SSH, firewall, ports, users, services, Docker, and package update information; read-only.
2. **SSH / firewall**: Checks SSH and UFW status, manages SSH ports and UFW rules, and offers a shortcut for SSH port `20001` and basic UFW rules.
3. **IPv6 status and configuration**: Checks local IPv6 status and can enable local IPv6 and UFW IPv6 support.
4. **BBR / fq status and configuration**: Shows congestion control status and can enable BBR and fq.
5. **Software and kernel updates**: Previews APT updates and runs `apt-get update` and `apt-get upgrade`; does not reboot automatically.
6. **Service management**: Checks common systemd services and can start, stop, restart, or reload them.
7. **Listening port inspection**: Shows TCP/UDP listeners, address family, bind address, and process.
8. **Fail2Ban management**: Shows jails and banned IPs, unbans IPs, and displays logs.
9. **Users and SSH keys**: Lists users, creates regular users, adds users to the sudo group, and adds SSH public keys; can disable root password login after key-login verification.
10. **Resource monitoring**: Shows load, memory, disk, inodes, and high-usage processes; read-only.
11. **Log viewer**: Displays SSH, Fail2Ban, UFW, and service error logs; read-only and does not write report files.
12. **Docker management**: Shows containers and port mappings; can start, stop, or restart containers.
13. **Scheduled task management**: Shows systemd timers and adds or removes Cron jobs for the root user.
14. **Safe cleanup**: Previews and cleans the APT cache, systemd journals, stopped containers, or dangling Docker images.
15. **Network security check**: Shows addresses, routes, DNS, and public IP, and reminds you to check cloud security groups; read-only.
16. **Export configuration status**: Prints SSH, UFW, Fail2Ban, and Docker status to the terminal without creating files.

## Run

Run the menu from the project directory:

```bash
sudo bash vps-guard.sh ui
```

Run command-line checks and recommendations:

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

## Notes

- Root access is required. Ubuntu/Debian systems using APT are the primary supported platforms.
- Start with the information audit. System-changing actions require `APPLY` confirmation.
- SSH, firewall, and network changes may disconnect remote access. Ensure that a VPS console or rescue path is available. After changing the SSH port, verify login from a second terminal before considering removal of the old rule.
- The tool does not automatically back up or roll back configuration. Review cleanup previews carefully; removed data may not be recoverable.
- Updates do not reboot automatically. After updating, check whether the system requires a reboot.
