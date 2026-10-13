#!/usr/bin/env bash

harden_ssh_root_password() {
  root_required || return 1
  [ -s /root/.ssh/authorized_keys ] || { danger "$(msg key_missing)"; return 1; }
  have sshd || return 1
  printf 'Have you opened a second SSH session using this root key and verified login? Type KEY-LOGIN-VERIFIED / 已用 root 公钥在第二个 SSH 会话验证成功？请输入 KEY-LOGIN-VERIFIED: '
  read -r key_login_verified
  [ "$key_login_verified" = KEY-LOGIN-VERIFIED ] || { say cancel; return 1; }
  backup_begin || return 1
  backup_file /etc/ssh/sshd_config || return 1
  say backup
  sed -i -E '/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config
  printf '\nPermitRootLogin prohibit-password\n' >> /etc/ssh/sshd_config
  if sshd -t 2>/dev/null && sshd -T 2>/dev/null | grep -qx 'permitrootlogin prohibit-password'; then
    if systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null; then
      say validated
    else
      say rollback
      rollback_latest
      systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
      return 1
    fi
  else
    say rollback
    rollback_latest
    return 1
  fi
}
