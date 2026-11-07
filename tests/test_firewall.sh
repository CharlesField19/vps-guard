#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
[ "$(id -u)" -eq 0 ] || skip 'root is required for the firewall shortcut test'

. "$ROOT/lib/common.sh"
. "$ROOT/lib/i18n.sh"
. "$ROOT/lib/net.sh"
. "$ROOT/lib/ssh.sh"
. "$ROOT/lib/ssh_shortcut.sh"
. "$ROOT/lib/ufw.sh"
. "$ROOT/modules/menu.sh"
VPS_GUARD_LANG=en

tmp=$(make_tmp)
trap 'rm -rf -- "$tmp"' EXIT

export VPS_GUARD_SSH_DIR=$tmp/ssh
export VPS_GUARD_SSH_BACKUP_DIR=$tmp/ssh-backups
export VPS_GUARD_SYSTEMD_DIR=$tmp/systemd
export VPS_GUARD_UFW_DEFAULTS=$tmp/ufw-defaults
export MOCK_LOG=$tmp/mock.log
export PATH="$ROOT/tests/mocks:$PATH"
for mock in ufw systemctl sshd ss; do
  [ "$(command -v "$mock")" = "$ROOT/tests/mocks/$mock" ] || fail "mock $mock is not first in PATH"
done
export MOCK_SS_OUTPUT='LISTEN 0 128 0.0.0.0:20001 0.0.0.0:*'
export MOCK_UFW_INCOMING=deny
export MOCK_UFW_OUTGOING=allow

reset_fixture() {
  rm -rf -- "$VPS_GUARD_SSH_DIR" "$VPS_GUARD_SYSTEMD_DIR"
  mkdir -p "$VPS_GUARD_SSH_DIR/sshd_config.d" "$VPS_GUARD_SYSTEMD_DIR"
  printf 'Port 22\n' > "$VPS_GUARD_SSH_DIR/sshd_config"
  printf 'DEFAULT_INPUT_POLICY="DROP"\n' > "$VPS_GUARD_UFW_DEFAULTS"
  : > "$MOCK_LOG"
}

line_of() {
  grep -n "$1" "$MOCK_LOG" | head -n 1 | cut -d: -f1
}

reset_fixture
ssh_shortcut
status=$?
[ "$status" -eq 0 ] || fail "success path returned $status"
[ "$SSH_CHANGE_RESULT" = ok ] || fail "unexpected result: $SSH_CHANGE_RESULT"
grep -qx 'Port 20001' "$VPS_GUARD_SSH_DIR/sshd_config" || fail 'SSH port was not switched to 20001'
count=$(grep -c '^Port ' "$VPS_GUARD_SSH_DIR/sshd_config")
[ "$count" -eq 1 ] || fail "expected one Port line, found $count"

allow22=$(line_of 'ufw allow 22/tcp')
deny=$(line_of 'ufw default deny incoming')
reload=$(line_of 'systemctl reload ssh')
[ -n "$allow22" ] || fail 'current SSH port was not allowed'
[ -n "$deny" ] || fail 'UFW default deny was not called'
[ -n "$reload" ] || fail 'SSH was not reloaded'
[ "$allow22" -lt "$deny" ] || fail "allow 22 ($allow22) must precede default deny ($deny)"
[ "$reload" -lt "$deny" ] || fail "SSH reload ($reload) must precede default deny ($deny)"
grep -q 'ufw allow 20001/tcp' "$MOCK_LOG" || fail 'new SSH port was not allowed'
grep -q 'ufw --force enable' "$MOCK_LOG" || fail 'UFW was not enabled'

reset_fixture
export MOCK_UFW_DENY_FAIL=1
export MOCK_UFW_INCOMING=allow
export MOCK_UFW_OUTGOING=allow
ssh_shortcut
status=$?
[ "$status" -ne 0 ] || fail 'deny failure was not reported'
[ "$SSH_CHANGE_RESULT" = ufw_policy_failed ] || fail "unexpected failure result: $SSH_CHANGE_RESULT"
grep -q 'ufw default allow incoming' "$MOCK_LOG" || fail 'original incoming policy was not restored'
grep -q 'ufw default allow outgoing' "$MOCK_LOG" || fail 'original outgoing policy was not restored'
grep -qx 'Port 20001' "$VPS_GUARD_SSH_DIR/sshd_config" || fail 'SSH should remain on 20001 after UFW rollback'
unset MOCK_UFW_DENY_FAIL MOCK_UFW_INCOMING MOCK_UFW_OUTGOING

echo 'firewall shortcut: OK'
