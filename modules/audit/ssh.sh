#!/usr/bin/env bash
audit_ssh() {
  heading ssh
  if ! have sshd; then notice 'sshd not found / 未发现 sshd'; return; fi
  local effective
  effective=$(sshd -T 2>/dev/null) || { notice 'Unable to read effective sshd configuration / 无法读取 sshd 生效配置'; return; }
  printf '%s\n' "$effective" | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|allowusers|allowgroups)' || true

  if printf '%s\n' "$effective" | grep -qx 'permitrootlogin yes'; then danger "$(msg root_password)"; fi
  if printf '%s\n' "$effective" | grep -qx 'passwordauthentication yes'; then notice 'Password authentication is enabled / 密码认证已启用'; fi
  if printf '%s\n' "$effective" | grep -qx 'pubkeyauthentication yes'; then pass 'Public-key authentication enabled / 已启用公钥认证'; else danger 'Public-key authentication disabled / 公钥认证已禁用'; fi

  local keys_found=0 key_file key_dir
  for key_file in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    [ -s "$key_file" ] || continue
    keys_found=1
    key_dir=${key_file%/authorized_keys}
    printf 'Authorized keys file / 公钥文件: %s\n' "$key_file"
    stat -c '  mode=%a owner=%U:%G / 权限=%a 所有者=%U:%G' "$key_file" 2>/dev/null || true
    if find "$key_file" -prune -perm /022 -print -quit 2>/dev/null | grep -q .; then
      notice "Check authorized_keys permissions / 请检查公钥文件权限: $key_file"
    fi
    [ -d "$key_dir" ] && stat -c '  ssh dir mode=%a owner=%U:%G / SSH目录权限=%a 所有者=%U:%G' "$key_dir" 2>/dev/null || true
  done
  [ "$keys_found" -eq 1 ] || danger "$(msg key_missing)"
}
