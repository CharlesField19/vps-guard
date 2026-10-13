#!/usr/bin/env bash
set -u
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE_DIR=${VPS_GUARD_STATE_DIR:-/var/lib/vps-guard}

have() { command -v "$1" >/dev/null 2>&1; }
root_required() { [ "$(id -u)" -eq 0 ] || { echo 'Root privileges required.' >&2; return 1; }; }
run_quiet() { "$@" 2>/dev/null; }
backup_path() { printf '%s/%s' "$STATE_DIR" "$1"; }
ensure_state() { install -d -m 700 "$STATE_DIR"; }
