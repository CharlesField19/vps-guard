#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
[ "$(id -u)" -eq 0 ] || skip 'root is required for the SSH port test'

. "$ROOT/lib/common.sh"
. "$ROOT/lib/net.sh"
. "$ROOT/lib/ssh.sh"
. "$ROOT/lib/ssh_port.sh"

tmp=$(make_tmp)
trap 'rm -rf -- "$tmp"' EXIT
export VPS_GUARD_SSH_DIR=$tmp/ssh
export VPS_GUARD_SSH_BACKUP_DIR=$tmp/ssh-backups
export VPS_GUARD_SYSTEMD_DIR=$tmp/systemd
export MOCK_LOG=$tmp/mock.log
export PATH="$ROOT/tests/mocks:$PATH"
for mock in ufw systemctl sshd ss; do
  [ "$(command -v "$mock")" = "$ROOT/tests/mocks/$mock" ] || fail "mock $mock is not first in PATH"
done
export MOCK_SS_OUTPUT=$'LISTEN 0 128 0.0.0.0:22 0.0.0.0:*\nLISTEN 0 128 0.0.0.0:22022 0.0.0.0:*'

reset_fixture() {
  rm -rf -- "$VPS_GUARD_SSH_DIR" "$VPS_GUARD_SYSTEMD_DIR"
  mkdir -p "$VPS_GUARD_SSH_DIR/sshd_config.d" "$VPS_GUARD_SYSTEMD_DIR"
  printf 'Include %s/sshd_config.d/*.conf\nPort 20001\n' "$VPS_GUARD_SSH_DIR" > "$VPS_GUARD_SSH_DIR/sshd_config"
  printf 'Port 22\n' > "$VPS_GUARD_SSH_DIR/sshd_config.d/01-port.conf"
  : > "$MOCK_LOG"
}

reset_fixture
ssh_change_port 22022
status=$?
[ "$status" -eq 0 ] || fail "success path returned $status"
[ "$SSH_CHANGE_RESULT" = ok ] || fail "unexpected result: $SSH_CHANGE_RESULT"
assert_file "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf"
grep -qx 'Port 22' "$VPS_GUARD_SSH_DIR/sshd_config.d/01-port.conf" || fail 'existing drop-in was modified'
ports=$(sshd -T -f "$VPS_GUARD_SSH_DIR/sshd_config" 2>/dev/null | awk '$1 == "port" { print $2 }')
for p in 22 20001 22022; do
  printf '%s\n' "$ports" | grep -qx "$p" || fail "effective ports lost $p"
done

reset_fixture
export MOCK_SSHD_TEST_FAIL=1
ssh_change_port 22022
status=$?
[ "$status" -ne 0 ] || fail 'validation failure was not reported'
[ "$SSH_CHANGE_RESULT" = validate_failed ] || fail "unexpected validation result: $SSH_CHANGE_RESULT"
assert_no_file "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf"
unset MOCK_SSHD_TEST_FAIL

reset_fixture
export MOCK_SYSTEMCTL_ACTIVE=1
ssh_change_port 22022
status=$?
[ "$status" -eq 0 ] || fail "socket path returned $status"
[ "$SSH_CHANGE_RESULT" = ok ] || fail "unexpected socket result: $SSH_CHANGE_RESULT"
socket_file=$VPS_GUARD_SYSTEMD_DIR/ssh.socket.d/99-vps-guard.conf
assert_file "$socket_file"
grep -qx 'ListenStream=0.0.0.0:22' "$socket_file" || fail 'socket drop-in lost port 22'
grep -qx 'ListenStream=0.0.0.0:22022' "$socket_file" || fail 'socket drop-in lost the new port'

reset_fixture
export MOCK_SYSTEMCTL_ACTIVE=1
export MOCK_SYSTEMCTL_RESTART_FAIL=1
ssh_change_port 22022
status=$?
[ "$status" -ne 0 ] || fail 'socket restart failure was not reported'
[ "$SSH_CHANGE_RESULT" = socket_failed ] || fail "unexpected socket failure result: $SSH_CHANGE_RESULT"
assert_no_file "$socket_file"
assert_no_file "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf"
unset MOCK_SYSTEMCTL_ACTIVE MOCK_SYSTEMCTL_RESTART_FAIL

echo 'ssh port change: OK'
