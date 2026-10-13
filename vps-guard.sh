#!/usr/bin/env bash
set -u

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LANGUAGE=zh
# shellcheck source=lib/i18n.sh
. "$BASE_DIR/lib/i18n.sh"
# shellcheck source=lib/common.sh
. "$BASE_DIR/lib/common.sh"
# shellcheck source=lib/backup.sh
. "$BASE_DIR/lib/backup.sh"
# shellcheck disable=SC1090
for file in "$BASE_DIR"/modules/audit/*.sh "$BASE_DIR"/modules/audit.sh "$BASE_DIR"/modules/harden/*.sh "$BASE_DIR"/modules/menu.sh; do
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
  sudo bash vps-guard.sh rollback
EOF
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
    1) LANGUAGE=zh ;;
    2) LANGUAGE=en ;;
    *) echo 'Invalid choice / 无效选择'; return 2 ;;
  esac
  ui_main_menu
}

rollback() {
  root_required || return 1
  if rollback_latest; then echo 'Rollback complete / 回滚完成'; else echo 'No rollback available / 没有可用的回滚点'; return 1; fi
}

case "${1:-ui}" in
  ui) root_required && ui;;
  audit) [ "${2:-}" = en ] && LANGUAGE=en; root_required && audit_all;;
  plan) [ "${2:-}" = en ] && LANGUAGE=en; root_required && plan;;
  harden)
    [ "${2:-}" = ssh-root-password ] || { usage; exit 2; }
    root_required && harden_ssh_root_password;;
  rollback) rollback;;
  -h|--help|help) usage;;
  *) usage >&2; exit 2;;
esac
