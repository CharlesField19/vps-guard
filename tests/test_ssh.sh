#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
[ "$(id -u)" -eq 0 ] || skip 'root is required for the SSH configuration test'
command -v sshd >/dev/null 2>&1 || skip 'sshd is required for the SSH configuration test'

. "$ROOT/lib/common.sh"
. "$ROOT/lib/i18n.sh"
. "$ROOT/lib/ssh.sh"
. "$ROOT/modules/harden/ssh.sh"

tmp=$(make_tmp)
trap 'rm -rf -- "$tmp"' EXIT

export VPS_GUARD_SSH_DIR=$tmp/ssh
export VPS_GUARD_SSH_BACKUP_DIR=$tmp/ssh-backups
mkdir -p "$VPS_GUARD_SSH_DIR/sshd_config.d"
printf 'Include %s/sshd_config.d/*.conf\nPort 20001\n' "$VPS_GUARD_SSH_DIR" > "$VPS_GUARD_SSH_DIR/sshd_config"
printf 'Port 22\n' > "$VPS_GUARD_SSH_DIR/sshd_config.d/01-port.conf"

ssh_config_backup "$tmp/backup" || fail 'backup failed'
ls -1 "$VPS_GUARD_SSH_BACKUP_DIR"/ssh-* >/dev/null 2>&1 || fail 'persistent SSH backup was not created'
ssh_write_keepalive_ports 22022 || fail 'port write failed'
assert_file "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf"
grep -qx 'Port 22' "$VPS_GUARD_SSH_DIR/sshd_config.d/01-port.conf" || fail 'existing drop-in was modified'
ports=$(sshd -T -f "$VPS_GUARD_SSH_DIR/sshd_config" 2>/dev/null | awk '$1 == "port" { print $2 }' | sort -n | tr '\n' ' ')
for p in 22 20001 22022; do
  printf '%s\n' " $ports " | grep -q " $p " || fail "effective ports lost $p: [$ports]"
done

ssh_config_restore "$tmp/backup" || fail 'restore failed'
assert_no_file "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf"
grep -qx 'Port 22' "$VPS_GUARD_SSH_DIR/sshd_config.d/01-port.conf" || fail 'restore lost the existing drop-in'

# The hardening tests use command mocks so no service is reloaded.
export MOCK_LOG=$tmp/mock.log
export PATH="$ROOT/tests/mocks:$PATH"
for mock in systemctl sshd; do
  [ "$(command -v "$mock")" = "$ROOT/tests/mocks/$mock" ] || fail "mock $mock is not first in PATH"
done
export VPS_GUARD_ROOT_AUTHORIZED_KEYS=$tmp/root_keys
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTestOnly test\n' > "$VPS_GUARD_ROOT_AUTHORIZED_KEYS"
printf 'Include %s/sshd_config.d/*.conf\nPort 22\nPermitRootLogin yes\n' "$VPS_GUARD_SSH_DIR" > "$VPS_GUARD_SSH_DIR/sshd_config"
printf 'PermitRootLogin yes\n' > "$VPS_GUARD_SSH_DIR/sshd_config.d/50-cloud-init.conf"
: > "$MOCK_LOG"

# OpenSSH 9.6 reports prohibit-password as the equivalent without-password.
printf 'Port 22\nPermitRootLogin without-password\n' > "$VPS_GUARD_SSH_DIR/sshd_config"
ssh_root_password_disabled || fail 'without-password alias was rejected'
printf 'Include %s/sshd_config.d/*.conf\nPort 22\nPermitRootLogin yes\n' "$VPS_GUARD_SSH_DIR" > "$VPS_GUARD_SSH_DIR/sshd_config"

printf 'y\n' | harden_ssh_root_password >/dev/null 2>&1
status=$?
[ "$status" -eq 0 ] || fail "harden success path returned $status"
assert_file "$VPS_GUARD_SSH_DIR/sshd_config.d/00-vps-guard-root.conf"
grep -q '^PermitRootLogin prohibit-password$' "$VPS_GUARD_SSH_DIR/sshd_config.d/00-vps-guard-root.conf" || fail 'managed root setting missing'
if grep -q '^PermitRootLogin' "$VPS_GUARD_SSH_DIR/sshd_config.d/50-cloud-init.conf"; then
  fail 'drop-in PermitRootLogin was not removed'
fi
sshd -T -f "$VPS_GUARD_SSH_DIR/sshd_config" -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null | grep -qxE 'permitrootlogin (prohibit-password|without-password)' || fail 'root context is not hardened'

# A validation failure must restore every file byte-for-byte.
rm -f "$VPS_GUARD_SSH_DIR/sshd_config.d/00-vps-guard-root.conf"
printf 'Include %s/sshd_config.d/*.conf\nPort 22\nPermitRootLogin yes\n' "$VPS_GUARD_SSH_DIR" > "$VPS_GUARD_SSH_DIR/sshd_config"
printf 'PermitRootLogin yes\n' > "$VPS_GUARD_SSH_DIR/sshd_config.d/50-cloud-init.conf"
snapshot() { find "$VPS_GUARD_SSH_DIR" -type f -print0 | sort -z | xargs -0 sha256sum; }
before=$(snapshot)
export MOCK_SSHD_TEST_FAIL=1
printf 'y\n' | harden_ssh_root_password >/dev/null 2>&1
status=$?
[ "$status" -ne 0 ] || fail 'validation failure was not reported'
after=$(snapshot)
[ "$before" = "$after" ] || fail 'failed hardening did not restore the SSH files'
unset MOCK_SSHD_TEST_FAIL

echo 'ssh configuration: OK'
