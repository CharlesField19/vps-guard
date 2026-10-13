#!/usr/bin/env bash
audit_users() {
  heading users
  awk -F: '$3 == 0 {print "UID 0: " $1}' /etc/passwd 2>/dev/null || true
  getent group sudo 2>/dev/null || true
  getent group adm 2>/dev/null || true
  echo 'Successful logins / 成功登录:'
  last -n 15 2>/dev/null || true
  echo 'Failed logins / 失败登录:'
  lastb -n 15 2>/dev/null || true
  journalctl -u ssh -u sshd --since '14 days ago' --no-pager 2>/dev/null | grep -E 'Accepted (password|publickey)' | tail -n 20 || true
}
