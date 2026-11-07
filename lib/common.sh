#!/usr/bin/env bash
set -u
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Path overrides exist for tests; production uses the standard locations.
: "${VPS_GUARD_SSH_DIR:=/etc/ssh}"
: "${VPS_GUARD_SYSTEMD_DIR:=/etc/systemd/system}"
: "${VPS_GUARD_UFW_DEFAULTS:=/etc/default/ufw}"
: "${VPS_GUARD_ROOT_AUTHORIZED_KEYS:=/root/.ssh/authorized_keys}"
: "${VPS_GUARD_SSH_BACKUP_DIR:=/var/backups/vps-guard}"

have() { command -v "$1" >/dev/null 2>&1; }
is_yes() { case "${1,,}" in y|yes) return 0 ;; *) return 1 ;; esac; }
root_required() { [ "$(id -u)" -eq 0 ] || { echo 'Root privileges required.' >&2; return 1; }; }
run_quiet() { "$@" 2>/dev/null; }
