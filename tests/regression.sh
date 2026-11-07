#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"
# shellcheck source=../lib/net.sh
. "$ROOT/lib/net.sh"
# shellcheck source=../lib/ssh.sh
. "$ROOT/lib/ssh.sh"
# shellcheck source=../lib/keys.sh
. "$ROOT/lib/keys.sh"
# shellcheck source=../lib/fail2ban.sh
. "$ROOT/lib/fail2ban.sh"
VPS_GUARD_SOURCE_ONLY=1
# shellcheck source=../install.sh
. "$ROOT/install.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

sample=$'Status\n|- Number of jail:\t2\n`- Jail list:\tsshd, recidive\n'
jails=$(printf '%s\n' "$sample" | fail2ban_jail_names)
[ "$jails" = $'sshd\nrecidive' ] || fail "jail parser got [$jails]"
printf '%s\n' 'Status' | fail2ban_jail_names | grep -q . && fail 'jail parser matched a line without Jail list'

ss_sample=$'LISTEN 0 128 0.0.0.0:22 0.0.0.0:*\nLISTEN 0 128 [::]:22022 [::]:*'
printf '%s\n' "$ss_sample" | tcp_port_in_ss_lines 22 || fail 'missed listening port 22'
printf '%s\n' "$ss_sample" | tcp_port_in_ss_lines 22022 || fail 'missed listening port 22022'
if printf '%s\n' "$ss_sample" | tcp_port_in_ss_lines 128; then
  fail 'Send-Q 128 was treated as a listening port'
fi

printf '%s\n' 'port 22' 'port 22022' | ssh_effective_has_ports 22 22022 || fail 'effective port check missed a required port'
if printf '%s\n' 'port 22022' | ssh_effective_has_ports 22 22022; then
  fail 'effective port check accepted a config without port 22'
fi

install_dir_safe /opt/vps-guard || fail 'default install path was rejected'
install_dir_safe /opt/vps-guard/ || fail 'trailing slash on a safe install path was rejected'
install_dir_safe / && fail 'refused path / was accepted'
install_dir_safe /opt && fail 'refused path /opt was accepted'
install_dir_safe /etc && fail 'refused path /etc was accepted'
install_dir_safe relative && fail 'relative install path was accepted'
install_dir_safe /opt/vps-guard/../etc && fail 'install path containing .. was accepted'
install_dir_safe /usr/local/bin && fail 'system bin path was accepted'
install_dir_safe /var/log/vps-guard && fail 'system log path was accepted'
install_dir_safe /tmp/vps-guard && fail 'temporary directory install path was accepted'
tmp=$(mktemp -d)
ln -s / "$tmp/link"
install_dir_safe "$tmp/link" && fail 'symlink install path was accepted'
rm -rf -- "$tmp"

text=$(ssh_socket_dropin_text 22022 0)
printf '%s\n' "$text" | grep -qx 'ListenStream=0.0.0.0:22' || fail 'IPv4 port 22 missing from socket drop-in'
printf '%s\n' "$text" | grep -qx 'ListenStream=0.0.0.0:22022' || fail 'new IPv4 port missing from socket drop-in'
printf '%s\n' "$text" | grep -q '\[::\]' && fail 'IPv6 listener written while IPv6 was disabled'
text=$(ssh_socket_dropin_text 22022 1)
printf '%s\n' "$text" | grep -qx 'ListenStream=\[::\]:22' || fail 'IPv6 port 22 missing when enabled'
printf '%s\n' "$text" | grep -qx 'ListenStream=\[::\]:22022' || fail 'new IPv6 port missing when enabled'

tmp=$(mktemp -d)
mkdir -p "$tmp/d"
printf 'Port 20001\n' > "$tmp/d/01-port.conf"
ssh_port_dropin_text 22022 > "$tmp/d/99-vps-guard-ports.conf"
printf 'Include %s/d/*.conf\n' "$tmp" > "$tmp/sshd_config"
grep -qx 'Port 20001' "$tmp/d/01-port.conf" || fail 'existing Port drop-in was removed'
ports=$(sshd -T -f "$tmp/sshd_config" 2>/dev/null | awk '$1 == "port" { print $2 }' | sort -n | tr '\n' ' ')
printf '%s\n' "$ports" | grep -q '22' || fail "effective config lost port 22: [$ports]"
printf '%s\n' "$ports" | grep -q '20001' || fail "effective config removed an existing port: [$ports]"
printf '%s\n' "$ports" | grep -q '22022' || fail "effective config missed the new port: [$ports]"
rm -rf -- "$tmp"

key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTestOnly comment'
tmp=$(mktemp -d)
mkdir -p "$tmp/home" "$tmp/outside"
ln -s "$tmp/outside" "$tmp/home/.ssh"
append_authorized_key_at "$tmp/home" root "$key" root
status=$?
[ "$status" -eq 2 ] || fail "directory symlink was not refused (status $status)"
[ ! -e "$tmp/outside/authorized_keys" ] || fail 'key was written through a .ssh symlink'
rm -rf -- "$tmp"

tmp=$(mktemp -d)
mkdir -p "$tmp/home/.ssh"
printf 'ORIGINAL\n' > "$tmp/secret"
ln -s "$tmp/secret" "$tmp/home/.ssh/authorized_keys"
append_authorized_key_at "$tmp/home" root "$key" root
status=$?
[ "$status" -eq 2 ] || fail "file symlink was not refused (status $status)"
[ "$(cat "$tmp/secret")" = ORIGINAL ] || fail 'chmod/write followed authorized_keys symlink'
rm -rf -- "$tmp"

tmp=$(mktemp -d)
mkdir -p "$tmp/home"
append_authorized_key_at "$tmp/home" root "$key" root || fail 'normal key write failed'
[ -f "$tmp/home/.ssh/authorized_keys" ] && [ ! -L "$tmp/home/.ssh/authorized_keys" ] || fail 'authorized_keys was not a regular file'
grep -qx "$key" "$tmp/home/.ssh/authorized_keys" || fail 'authorized_keys content mismatch'
[ "$(stat -c '%a' "$tmp/home/.ssh/authorized_keys")" = 600 ] || fail 'authorized_keys mode was not 600'
rm -rf -- "$tmp"

python3 - "$ROOT" << 'PY' || fail 'static SSH checks failed'
import sys
from pathlib import Path
root = Path(sys.argv[1])
shortcut = (root / "lib/ssh_shortcut.sh").read_text()
listen = shortcut.index("tcp_port_listening 20001")
deny = shortcut.index("ufw default deny incoming")
if listen > deny:
    raise SystemExit("UFW default deny still happens before the port 20001 listener check")
port = (root / "lib/ssh_port.sh").read_text()
if "ssh_effective_has_ports 22" not in port:
    raise SystemExit("port change does not require port 22 to remain effective")
if "ListenStream=[::]" in port:
    raise SystemExit("port change still hardcodes an IPv6 socket listener")
PY

printf 'OK\n'
