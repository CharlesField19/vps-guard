# SSH and firewall recovery

The tool rolls back changes when validation, reload, or listener checks fail. A rollback cannot help if the current session is already disconnected, so keep a provider console, VNC, serial console, or rescue environment available before changing SSH or UFW.

## You changed the SSH port and cannot connect

1. Open the provider console or rescue shell.
2. Check the listener:

   ```bash
   ss -lntp | grep -E 'sshd|systemd'
   systemctl status ssh ssh.socket --no-pager
   ```

3. If the port is wrong, inspect `Port` lines in the main config and drop-ins:

   ```bash
   grep -RIn '^Port ' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
   ```

4. Add the port you can reach, or remove the managed drop-in and reload:

   ```bash
   rm -f /etc/ssh/sshd_config.d/99-vps-guard-ports.conf
   sshd -t
   systemctl restart ssh
   ```

5. If `ssh.socket` is used:

   ```bash
   rm -f /etc/systemd/system/ssh.socket.d/99-vps-guard.conf
   systemctl daemon-reload
   systemctl restart ssh.socket
   ```

6. Check the cloud security group for the same TCP port.

## UFW is blocking you

From a console or rescue shell:

```bash
ufw status verbose
ufw allow 22/tcp
ufw reload
```

If the current session is already lost and the provider console is unavailable, disable UFW from rescue mode:

```bash
ufw disable
```

Re-enable it after fixing the rules. Do not disable a firewall on an untrusted network longer than necessary.

## sshd configuration is invalid

```bash
sshd -t
```

Read the reported line and file. If the managed files were interrupted mid-write, remove the managed drop-ins and restore the previous values manually:

```bash
rm -f /etc/ssh/sshd_config.d/99-vps-guard-ports.conf
rm -f /etc/ssh/sshd_config.d/00-vps-guard-root.conf
sshd -t
systemctl restart ssh
```

The tool also writes a timestamped SSH configuration copy under `/var/backups/vps-guard/ssh-*` before changes. You can restore that copy from a console or rescue shell:

```bash
ls -1 /var/backups/vps-guard/ssh-*
cp -a /var/backups/vps-guard/ssh-<timestamp>/. /etc/ssh/
sshd -t
systemctl restart ssh
```

Make your own backup before manual edits as well:

```bash
cp -a /etc/ssh /root/ssh-backup-$(date +%Y%m%d-%H%M%S)
```

## Root password login was disabled by mistake

Use the provider console or rescue environment. Restore key login or re-enable password login temporarily:

```bash
grep -RIn '^PermitRootLogin' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
```

Remove the managed setting and set your intended policy, then validate:

```bash
rm -f /etc/ssh/sshd_config.d/00-vps-guard-root.conf
printf '\nPermitRootLogin yes\n' >> /etc/ssh/sshd_config
sshd -t
systemctl restart ssh
```

Return to key-only login as soon as access is restored.

## Prevention checklist

- Open a second SSH session before changing a port or firewall.
- Test the new port with `ssh -p <port> user@host`.
- Confirm `ss -lntp` shows both the old and new listeners before closing the old path.
- Keep the provider rescue console reachable.
- Take a manual copy of `/etc/ssh` before manual edits.
