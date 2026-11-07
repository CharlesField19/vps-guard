#!/usr/bin/env bash

# Change the SSH listener while keeping both 22 and the new port.
# Returns 0 on success; sets SSH_CHANGE_RESULT for the caller.
ssh_change_port() {
  local port=$1
  local socket_active=0 dropins='' dropin backup ipv6
  local socket_file socket_backup
  SSH_CHANGE_RESULT=
  SSH_CHANGE_UFW_MISSING=0
  SSH_CHANGE_IPV6_DISABLED=0

  if ! root_required; then
    SSH_CHANGE_RESULT=not_root
    return 1
  fi
  if ! have sshd || ! have systemctl || ! have ss; then
    SSH_CHANGE_RESULT=missing_tools
    return 1
  fi

  systemctl is-active --quiet ssh.socket 2>/dev/null && socket_active=1
  if [ "$socket_active" -eq 1 ]; then
    dropins=$(systemctl show --property=DropInPaths --value ssh.socket 2>/dev/null || true)
    for dropin in $dropins; do
      if [ "${dropin##*/}" != 99-vps-guard.conf ]; then
        SSH_CHANGE_RESULT=custom_socket_dropin
        return 1
      fi
    done
    if [ -e "$VPS_GUARD_SYSTEMD_DIR/ssh.socket.d/99-vps-guard.conf" ] && ! grep -q '^# Managed by VPS Guard$' "$VPS_GUARD_SYSTEMD_DIR/ssh.socket.d/99-vps-guard.conf"; then
      SSH_CHANGE_RESULT=unmanaged_socket_dropin
      return 1
    fi
  fi

  if have ufw; then
    if ! ufw allow 22/tcp || ! ufw allow "$port/tcp"; then
      SSH_CHANGE_RESULT=ufw_failed
      return 1
    fi
  else
    SSH_CHANGE_UFW_MISSING=1
  fi

  backup=$(mktemp -d) || { SSH_CHANGE_RESULT=backup_failed; return 1; }
  if ! ssh_config_backup "$backup" || ! ssh_write_keepalive_ports "$port"; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=write_failed
    return 1
  fi
  if ! sshd_validate_config || ! sshd_effective_config | ssh_effective_has_ports 22 "$port"; then
    ssh_config_restore "$backup" || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=validate_failed
    return 1
  fi

  if [ "$socket_active" -eq 1 ]; then
    socket_file=$VPS_GUARD_SYSTEMD_DIR/ssh.socket.d/99-vps-guard.conf
    socket_backup=$backup/ssh.socket.conf
    [ -f "$socket_file" ] && cp -a "$socket_file" "$socket_backup"
    ipv6=0
    ipv6_available && ipv6=1
    [ "$ipv6" -eq 0 ] && SSH_CHANGE_IPV6_DISABLED=1
    if ! install -d -m 755 "$VPS_GUARD_SYSTEMD_DIR/ssh.socket.d" || ! ssh_socket_dropin_text "$port" "$ipv6" > "$socket_file" || ! systemctl daemon-reload || ! systemctl restart ssh.socket; then
      if [ -f "$socket_backup" ]; then cp -a "$socket_backup" "$socket_file"; else rm -f -- "$socket_file"; fi
      systemctl daemon-reload >/dev/null 2>&1 || true
      systemctl restart ssh.socket >/dev/null 2>&1 || true
      ssh_config_restore "$backup" || true
      rm -rf -- "$backup"
      SSH_CHANGE_RESULT=socket_failed
      return 1
    fi
  elif ! ssh_reload_service; then
    ssh_config_restore "$backup" || true
    ssh_reload_service || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=reload_failed
    return 1
  fi

  if ! tcp_port_listening 22; then
    if [ "$socket_active" -eq 1 ]; then
      if [ -f "$socket_backup" ]; then cp -a "$socket_backup" "$socket_file"; else rm -f -- "$socket_file"; fi
      systemctl daemon-reload >/dev/null 2>&1 || true
      systemctl restart ssh.socket >/dev/null 2>&1 || true
    fi
    ssh_config_restore "$backup" || true
    [ "$socket_active" -eq 0 ] && ssh_reload_service || true
    rm -rf -- "$backup"
    SSH_CHANGE_RESULT=no22
    return 1
  fi

  rm -rf -- "$backup"
  if tcp_port_listening "$port"; then
    SSH_CHANGE_RESULT=ok
  else
    SSH_CHANGE_RESULT=no_new_port
  fi
  return 0
}
