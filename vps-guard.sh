#!/usr/bin/env bash
set -u

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VPS_GUARD_LANG=zh
VPS_GUARD_VERSION=$(cat "$BASE_DIR/VERSION" 2>/dev/null || echo unknown)
# shellcheck source=lib/i18n.sh
. "$BASE_DIR/lib/i18n.sh"
# shellcheck source=lib/common.sh
. "$BASE_DIR/lib/common.sh"
# shellcheck source=lib/net.sh
. "$BASE_DIR/lib/net.sh"
# shellcheck source=lib/ssh.sh
. "$BASE_DIR/lib/ssh.sh"
# shellcheck source=lib/ssh_port.sh
. "$BASE_DIR/lib/ssh_port.sh"
# shellcheck source=lib/ssh_shortcut.sh
. "$BASE_DIR/lib/ssh_shortcut.sh"
# shellcheck source=lib/keys.sh
. "$BASE_DIR/lib/keys.sh"
# shellcheck source=lib/fail2ban.sh
. "$BASE_DIR/lib/fail2ban.sh"
# shellcheck source=lib/ufw.sh
. "$BASE_DIR/lib/ufw.sh"
# shellcheck disable=SC1090
for file in "$BASE_DIR"/modules/audit/*.sh "$BASE_DIR"/modules/harden/*.sh "$BASE_DIR"/modules/menu.sh; do
  [ -f "$file" ] && . "$file"
done

usage() {
  cat <<'EOF'
vps-guard / VPS Guard

Usage:
  sudo bash vps-guard.sh ui
  sudo bash vps-guard.sh audit [zh|en]
  sudo bash vps-guard.sh plan [zh|en]
  sudo bash vps-guard.sh harden ssh-root-password
  sudo bash vps-guard.sh --version
EOF
  printf 'Version: %s\n' "$VPS_GUARD_VERSION"
}

plan() {
  audit_all
  heading recommend
  echo '1. Add and verify an SSH public key before disabling root password login.'
  echo '   在关闭 root 密码登录前，先添加并验证 SSH 公钥。'
  echo '2. Keep the existing UFW and Fail2Ban setup; avoid duplicate CrowdSec deployment initially.'
  echo '   保留现有 UFW 和 Fail2Ban，初期不要重复部署 CrowdSec。'
  echo '3. Expose only required Docker ports; keep management ports on 127.0.0.1.'
  echo '   只开放必要的 Docker 端口，管理端口保持监听 127.0.0.1。'
  echo '4. Enable auditd after confirming memory and service stability.'
  echo '   确认内存和服务稳定后，再启用 auditd。'
  echo '5. Apply kernel and package changes only during a maintenance window.'
  echo '   内核和软件包修改只在维护窗口执行。'
}

ui() {
  clear 2>/dev/null || true
  echo '1) 中文'
  echo '2) English'
  printf '> '
  read -r language_choice || return 0
  case "$language_choice" in
    1) VPS_GUARD_LANG=zh ;;
    2) VPS_GUARD_LANG=en ;;
    *) echo 'Invalid choice / 无效选择'; return 2 ;;
  esac
  ui_main_menu
}

case "${1:-ui}" in
  ui) root_required && ui;;
  audit)
    case "${2:-}" in en|EN) VPS_GUARD_LANG=en ;; esac
    root_required && audit_all
    ;;
  plan)
    case "${2:-}" in en|EN) VPS_GUARD_LANG=en ;; esac
    root_required && plan
    ;;
  harden)
    [ "${2:-}" = ssh-root-password ] || { usage; exit 2; }
    root_required && harden_ssh_root_password;;
  -h|--help|help) usage;;
  --version|-V) printf 'vps-guard %s\n' "$VPS_GUARD_VERSION";;
  *) usage >&2; exit 2;;
esac
