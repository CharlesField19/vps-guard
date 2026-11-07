#!/usr/bin/env bash

ufw_restore_defaults() {
  local incoming=$1 outgoing=$2 default_backup=$3
  [ -n "$incoming" ] && ufw default "$incoming" incoming >/dev/null 2>&1 || true
  [ -n "$outgoing" ] && ufw default "$outgoing" outgoing >/dev/null 2>&1 || true
  [ -n "$default_backup" ] && [ -f "$default_backup" ] && cp -a "$default_backup" "$VPS_GUARD_UFW_DEFAULTS"
}
