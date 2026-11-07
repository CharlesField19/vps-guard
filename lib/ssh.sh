#!/usr/bin/env bash

ssh_effective_has_ports() {
  awk -v required="$*" '
    BEGIN { n = split(required, want, " ") }
    $1 == "port" { seen[$2] = 1 }
    END {
      for (i = 1; i <= n; i++) if (!seen[want[i]]) exit 1
      exit n ? 0 : 1
    }
  '
}

ssh_port_dropin_text() {
  local port=$1
  printf '%s\n' '# Managed by VPS Guard' 'Port 22' "Port ${port}"
}

ssh_socket_dropin_text() {
  local port=$1 ipv6=${2:-0}
  printf '%s\n' '# Managed by VPS Guard' '[Socket]' 'ListenStream=' "ListenStream=0.0.0.0:22" "ListenStream=0.0.0.0:${port}"
  if [ "$ipv6" = 1 ]; then
    printf '%s\n' "ListenStream=[::]:22" "ListenStream=[::]:${port}"
  fi
}

sshd_config_file() { printf '%s/sshd_config' "$VPS_GUARD_SSH_DIR"; }

sshd_effective_config() { sshd -T -f "$VPS_GUARD_SSH_DIR/sshd_config" 2>/dev/null; }

sshd_validate_config() { sshd -t -f "$VPS_GUARD_SSH_DIR/sshd_config" 2>/dev/null; }

ssh_config_copy() {
  local dest=$1
  mkdir -p "$dest/sshd_config.d" || return 1
  [ -f "$VPS_GUARD_SSH_DIR/sshd_config" ] || return 1
  cp -a "$VPS_GUARD_SSH_DIR/sshd_config" "$dest/sshd_config" || return 1
  if [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ]; then
    find "$VPS_GUARD_SSH_DIR/sshd_config.d" -maxdepth 1 -type f -name '*.conf' -exec cp -a {} "$dest/sshd_config.d/" \; || return 1
  fi
}

ssh_config_backup() {
  local dest=$1 persist
  ssh_config_copy "$dest" || return 1
  if [ -n "${VPS_GUARD_SSH_BACKUP_DIR:-}" ]; then
    mkdir -p "$VPS_GUARD_SSH_BACKUP_DIR" || return 1
    persist=$(mktemp -d "$VPS_GUARD_SSH_BACKUP_DIR/ssh-$(date -u +%Y%m%dT%H%M%SZ).XXXXXX") || return 1
    ssh_config_copy "$persist" || return 1
  fi
}

ssh_config_restore() {
  local dest=$1 file base
  [ -f "$dest/sshd_config" ] || return 1
  cp -a "$dest/sshd_config" "$VPS_GUARD_SSH_DIR/sshd_config" || return 1
  if [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ]; then
    while IFS= read -r -d '' file; do
      base=${file##*/}
      if [ ! -e "$dest/sshd_config.d/$base" ]; then
        rm -f -- "$file"
      fi
    done < <(find "$VPS_GUARD_SSH_DIR/sshd_config.d" -maxdepth 1 -type f -name '*.conf' -print0)
    if [ -n "$(find "$dest/sshd_config.d" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
      cp -a "$dest/sshd_config.d/." "$VPS_GUARD_SSH_DIR/sshd_config.d/" || return 1
    fi
  fi
}

ssh_uses_dropins() {
  [ -f "$VPS_GUARD_SSH_DIR/sshd_config" ] || return 1
  grep -qE "^[[:space:]]*Include[[:space:]]+\"?${VPS_GUARD_SSH_DIR}/sshd_config\\.d/\\*\\.conf\"?[[:space:]]*$" "$VPS_GUARD_SSH_DIR/sshd_config"
}

ssh_write_keepalive_ports() {
  local port=$1
  case "$port" in ''|*[!0-9]*) return 1 ;; esac
  if ssh_uses_dropins || { [ -d "$VPS_GUARD_SSH_DIR/sshd_config.d" ] && grep -qE '^[[:space:]]*Include[[:space:]].*sshd_config\.d' "$VPS_GUARD_SSH_DIR/sshd_config"; }; then
    install -d -m 755 "$VPS_GUARD_SSH_DIR/sshd_config.d" || return 1
    ssh_port_dropin_text "$port" > "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf" || return 1
    chmod 644 "$VPS_GUARD_SSH_DIR/sshd_config.d/99-vps-guard-ports.conf" || return 1
    return 0
  fi
  [ -f "$VPS_GUARD_SSH_DIR/sshd_config" ] || return 1
  printf '\nPort 22\nPort %s\n' "$port" >> "$VPS_GUARD_SSH_DIR/sshd_config"
}

ssh_reload_service() {
  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null
}
