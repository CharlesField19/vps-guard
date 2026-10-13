#!/usr/bin/env bash

audit_baseline() {
  heading baseline
  local mode uid0_count=0

  if [ -e /etc/passwd ]; then
    uid0_count=$(awk -F: '$3 == 0 {n++} END {print n+0}' /etc/passwd 2>/dev/null)
    if [ "$uid0_count" -gt 1 ]; then
      danger "Multiple UID 0 accounts found / 发现多个 UID 0 账户（$uid0_count）"
      awk -F: '$3 == 0 {print "  UID 0: " $1}' /etc/passwd
    else
      pass 'UID 0 account count looks normal / UID 0 账户数量正常'
    fi
  fi

  for file in /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers /etc/ssh/sshd_config; do
    [ -e "$file" ] || continue
    mode=$(stat -c '%a' "$file" 2>/dev/null) || continue
    printf 'Permission / 权限: %s mode=%s\n' "$file" "$mode"
    case "$file" in
      */shadow|*/gshadow|*/sudoers)
        if find "$file" -prune -perm /037 -print -quit 2>/dev/null | grep -q .; then
          danger "Sensitive file has overly broad permissions / 敏感文件权限过宽: $file"
        fi
        ;;
      */sshd_config)
        if find "$file" -prune -perm /022 -print -quit 2>/dev/null | grep -q .; then
          danger "SSH config is group/world-writable / SSH 配置允许组或其他用户写入: $file"
        fi
        ;;
    esac
  done

  if [ -e /var/run/reboot-required ]; then
    notice 'A reboot is pending after updates / 更新后需要重启系统'
  fi
  if [ -r /etc/login.defs ]; then
    awk '/^[[:space:]]*UMASK[[:space:]]+/ {print "Login UMASK / 登录默认 UMASK: " $2}' /etc/login.defs
  fi
}
