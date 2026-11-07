#!/usr/bin/env bash

# Returns 2 when a user-controlled symlink would redirect a root write.
append_authorized_key_at() {
  local home=$1 group=$2 key=$3 username=$4
  local ssh_dir auth tmp
  [ -n "$home" ] && [ -d "$home" ] || return 1
  ssh_dir=$home/.ssh
  auth=$ssh_dir/authorized_keys
  if [ -L "$ssh_dir" ] || [ -L "$auth" ]; then
    return 2
  fi
  if [ -e "$ssh_dir" ] && [ ! -d "$ssh_dir" ]; then
    return 1
  fi
  if [ -e "$auth" ] && [ ! -f "$auth" ]; then
    return 1
  fi
  install -d -m 700 -o "$username" -g "$group" "$ssh_dir" || return 1
  if [ -L "$ssh_dir" ] || [ ! -d "$ssh_dir" ] || [ -L "$auth" ]; then
    return 2
  fi
  tmp=$(mktemp "$ssh_dir/authorized_keys.tmp.XXXXXX") || return 1
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  if [ -f "$auth" ]; then
    cat -- "$auth" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  fi
  printf '%s\n' "$key" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
  chown "$username:$group" "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  if [ -L "$ssh_dir" ] || [ -L "$auth" ]; then
    rm -f -- "$tmp"
    return 2
  fi
  # mv -T replaces a symlink at the destination instead of following it.
  mv -T -- "$tmp" "$auth" || { rm -f -- "$tmp"; return 1; }
  chown "$username:$group" "$auth" || return 1
  chmod 600 "$auth" || return 1
}

append_authorized_key() {
  local username=$1 key=$2 home group
  home=$(getent passwd "$username" | cut -d: -f6)
  group=$(id -gn -- "$username" 2>/dev/null) || return 1
  [ -n "$home" ] || return 1
  append_authorized_key_at "$home" "$group" "$key" "$username"
}
