#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"

. "$ROOT/lib/i18n.sh"
. "$ROOT/lib/common.sh"
. "$ROOT/lib/net.sh"
. "$ROOT/lib/ssh.sh"
. "$ROOT/lib/ssh_port.sh"
. "$ROOT/lib/ssh_shortcut.sh"
. "$ROOT/lib/keys.sh"
. "$ROOT/lib/fail2ban.sh"
. "$ROOT/lib/ufw.sh"
for file in "$ROOT"/modules/audit/*.sh "$ROOT"/modules/harden/*.sh "$ROOT"/modules/menu.sh; do
  [ -f "$file" ] && . "$file"
done

for fn in \
  audit_all ui_text ui_pause ui_main_menu ui_ssh_port_menu ui_apply_ssh_firewall \
  ui_ufw_rules_menu ui_users_keys_menu ui_fail2ban_menu ui_docker_menu \
  harden_ssh_root_password append_authorized_key ssh_config_backup ssh_config_restore \
  ssh_change_port ssh_shortcut tcp_port_listening fail2ban_jail_names ufw_restore_defaults; do
  declare -F "$fn" >/dev/null || fail "missing function: $fn"
done

printf 'load: OK\n'
