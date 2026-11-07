#!/usr/bin/env bash

# Apply the 20001 shortcut: allow the current SSH port first, switch SSH to
# 20001, then change UFW defaults and enable UFW.
# Returns 0 on success; sets SSH_CHANGE_RESULT for the caller.
ssh_shortcut() {
  local backup current_ports p incoming outgoing ufw_default_backup
  local config_file effective_config
  SSH_CHANGE_RESULT=

  if ! root_required; then
    SSH_CHANGE_RESULT=not_root
    return 1
  fi
  if ! have sshd; then
    SSH_CHANGE_RESULT=no_sshd
    return 1
  fi
  if ! have ufw; then
    SSH_CHANGE_RESULT=no_ufw
    return 1
  fi
  if have systemctl && systemctl is-active --quiet ssh.socket 2>/dev/null; then
    SSH_CHANGE_RESULT=socket_active
    return 1
  fi

  current_ports=$(sshd_effective_config | awk '$1 == "port" { print $2 }')
  for p in $current_ports 20001 80 443; do
    if ! ufw allow "$p/tcp"; then
      SSH_CHANGE_RESULT=ufw_allow_failed
      return 1
    fi
  done

  incoming=$(LC_ALL=C ufw status verbose 2>/dev/null | sed -n 's/^Default: \([A-Za-z]*\) (incoming).*/\1/p')
  outgoing=$(LC_ALL=C ufw status verbose 2>/dev/null | sed -n 's/^Default: [A-Za-z]* (incoming), \([A-Za-z]*\) (outgoing).*/\1/p')
  backup=$(mktemp -d) || { SSH_CHANGE_RESULT=backup_failed; return 1; }
  if ! ssh_config_backup "$backup"; then
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=backup_failed
    return 1
  fi

  # This shortcut intentionally leaves only port 20001. Drop-in Port lines are
  # cumulative, so they must be cleared or the old port remains effective.
  if [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ]; then
    while IFS= read -r -d '' config_file; do
      if ! sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' "$config_file"; then
        ssh_config_restore "$backup" || true
        rm -rf -- "$backup"
        SSH_CHANGE_RESULT=dropin_failed
        return 1
      fi
    done < <(find "$VPS_GUARD_SSH_DIR/sshd_config.d" -maxdepth 1 -type f -name '*.conf' -print0)
  fi
  if ! sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' "$VPS_GUARD_SSH_DIR/sshd_config" || ! printf '\nPort 20001\n' >> "$VPS_GUARD_SSH_DIR/sshd_config"; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=main_failed
    return 1
  fi
  effective_config=$(sshd_effective_config) || effective_config=
  if ! sshd_validate_config || ! printf '%s\n' "$effective_config" | awk '$1 == "port" { count++; if ($2 != "20001") invalid=1 } END { exit !(count == 1 && !invalid) }'; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=validate_failed
    return 1
  fi
  if ! ssh_reload_service; then
    ssh_config_restore "$backup" || true
    ssh_reload_service || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=reload_failed
    return 1
  fi
  if ! tcp_port_listening 20001; then
    ssh_config_restore "$backup" || true
    ssh_reload_service || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=no20001
    return 1
  fi

  ufw_default_backup=$backup/default-ufw
  [ -f "$VPS_GUARD_UFW_DEFAULTS" ] && cp -a "$VPS_GUARD_UFW_DEFAULTS" "$ufw_default_backup"
  if [ -f "$VPS_GUARD_UFW_DEFAULTS" ]; then
    sed -i -E 's/^[[:space:]]*IPV6=.*/IPV6=yes/' "$VPS_GUARD_UFW_DEFAULTS"
    grep -q '^IPV6=' "$VPS_GUARD_UFW_DEFAULTS" || printf '\nIPV6=yes\n' >> "$VPS_GUARD_UFW_DEFAULTS"
  fi
  if ! ufw default deny incoming || ! ufw default allow outgoing || ! ufw --force enable; then
    ufw_restore_defaults "$incoming" "$outgoing" "$ufw_default_backup"
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=ufw_policy_failed
    return 1
  fi
  rm -rf -- "$backup"
  SSH_CHANGE_RESULT=ok
  return 0
}
