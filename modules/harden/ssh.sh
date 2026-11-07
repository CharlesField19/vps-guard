#!/usr/bin/env bash

ssh_root_password_disabled() {
  local effective
  sshd_validate_config || return 1
  effective=$(sshd_effective_config) || return 1
  printf '%s\n' "$effective" | grep -qxE 'permitrootlogin (prohibit-password|without-password)' || return 1
  effective=$(sshd -T -f "$VPS_GUARD_SSH_DIR/sshd_config" -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null) || return 1
  printf '%s\n' "$effective" | grep -qxE 'permitrootlogin (prohibit-password|without-password)'
}

harden_ssh_root_password() {
  local backup config_file key_login_verified managed="$VPS_GUARD_SSH_DIR/sshd_config.d/00-vps-guard-root.conf"
  root_required || return 1
  [ -s "$VPS_GUARD_ROOT_AUTHORIZED_KEYS" ] || { danger "$(msg key_missing)"; return 1; }
  have sshd || return 1
  printf 'Have you opened a second SSH session using this root key and verified login? Enter y/n / 已用 root 公钥在第二个 SSH 会话验证成功？请输入 y/n: '
  read -r key_login_verified
  is_yes "$key_login_verified" || { say cancel; return 1; }

  backup=$(mktemp -d) || return 1
  if ! ssh_config_backup "$backup"; then
    rm -rf -- "$backup"
    printf '%s\n' 'Unable to back up SSH configuration; no changes made. / 无法备份 SSH 配置，未修改系统。'
    return 1
  fi

  if [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ]; then
    while IFS= read -r -d '' config_file; do
      if ! sed -i -E '/^[[:space:]]*PermitRootLogin[[:space:]]/d' "$config_file"; then
        ssh_config_restore "$backup" || true
        rm -rf -- "$backup"
        printf '%s\n' 'Failed to update an SSH drop-in; configuration was restored. / 修改 SSH drop-in 失败，已恢复配置。'
        return 1
      fi
    done < <(find "$VPS_GUARD_SSH_DIR/sshd_config.d" -maxdepth 1 -type f -name '*.conf' -print0)
  fi
  if ! sed -i -E '/^[[:space:]]*PermitRootLogin[[:space:]]/d' "$VPS_GUARD_SSH_DIR/sshd_config"; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    printf '%s\n' 'Failed to update sshd_config; configuration was restored. / 修改 sshd_config 失败，已恢复配置。'
    return 1
  fi
  if [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ] && grep -qE '^[[:space:]]*Include[[:space:]].*sshd_config\.d' "$VPS_GUARD_SSH_DIR/sshd_config"; then
    if ! install -d -m 755 "$VPS_GUARD_SSH_DIR/sshd_config.d"; then
      ssh_config_restore "$backup" || true
      rm -rf -- "$backup"
      printf '%s\n' 'Failed to write the managed SSH drop-in; configuration was restored. / 写入托管 SSH drop-in 失败，已恢复配置。'
      return 1
    fi
    if ! cat > "$managed" <<'EOF'
# Managed by VPS Guard
PermitRootLogin prohibit-password
EOF
    then
      ssh_config_restore "$backup" || true
      rm -rf -- "$backup"
      printf '%s\n' 'Failed to write the managed SSH drop-in; configuration was restored. / 写入托管 SSH drop-in 失败，已恢复配置。'
      return 1
    fi
  elif ! printf '\nPermitRootLogin prohibit-password\n' >> "$VPS_GUARD_SSH_DIR/sshd_config"; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    printf '%s\n' 'Failed to update sshd_config; configuration was restored. / 修改 sshd_config 失败，已恢复配置。'
    return 1
  fi

  if ! ssh_root_password_disabled; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    printf '%s\n' 'SSH configuration validation failed; configuration was restored. / SSH 配置验证失败，已恢复配置。'
    return 1
  fi
  if ssh_reload_service; then
    rm -rf -- "$backup"
    say validated
  else
    ssh_config_restore "$backup" || true
    ssh_reload_service || true
    rm -rf -- "$backup"
    printf '%s\n' 'SSH reload failed; configuration was restored. / SSH 重载失败，已恢复配置。'
    return 1
  fi
}
