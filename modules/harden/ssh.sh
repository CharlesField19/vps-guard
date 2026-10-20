#!/usr/bin/env bash

harden_ssh_root_password() {
  root_required || return 1
  [ -s /root/.ssh/authorized_keys ] || { danger "$(msg key_missing)"; return 1; }
  have sshd || return 1
  printf 'Have you opened a second SSH session using this root key and verified login? Enter y/n / 已用 root 公钥在第二个 SSH 会话验证成功？请输入 y/n: '
  read -r key_login_verified
  is_yes "$key_login_verified" || { say cancel; return 1; }
  sed -i -E '/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config
  printf '\nPermitRootLogin prohibit-password\n' >> /etc/ssh/sshd_config
  if sshd -t 2>/dev/null && sshd -T 2>/dev/null | grep -qx 'permitrootlogin prohibit-password'; then
    if systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null; then
      say validated
    else
      printf '%s\n' 'SSH reload failed; configuration was not automatically reverted. / SSH 重载失败；未自动回滚配置。'
      return 1
    fi
  else
    printf '%s\n' 'SSH configuration validation failed; configuration was not automatically reverted. / SSH 配置验证失败；未自动回滚配置。'
    return 1
  fi
}
