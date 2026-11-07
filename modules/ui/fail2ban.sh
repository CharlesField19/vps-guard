#!/usr/bin/env bash

ui_fail2ban_menu() {
  local choice status_text jail_index jail ip confirm package_action package_ok
  local -a jails=()
  while true; do
    jails=()
    if have fail2ban-client && fail2ban-client ping >/dev/null 2>&1; then
      status_text=$(fail2ban-client status 2>/dev/null || true)
      printf '\n%s\n' "$status_text"
      mapfile -t jails < <(printf '%s\n' "$status_text" | fail2ban_jail_names)
    else
      printf '%s\n' "$(ui_text 'Fail2Ban 未安装、未运行或客户端无法连接。可用选项 4 安装/更新。' 'Fail2Ban is not installed, not running, or unreachable. Use option 4 to install/update it.')"
    fi
    printf '%s\n' \
      "1) $(ui_text '查看 Jail 状态和封禁 IP' 'View jail status and banned IPs')" \
      "2) $(ui_text '解封 IP' 'Unban an IP')" \
      "3) $(ui_text '查看 Fail2Ban 日志' 'View Fail2Ban logs')" \
      "4) $(ui_text '安装/更新 Fail2Ban' 'Install/update Fail2Ban')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1|2)
        if ! have fail2ban-client || ! fail2ban-client ping >/dev/null 2>&1; then
          printf '%s\n' "$(ui_text 'Fail2Ban 当前不可用，请先执行选项 4。' 'Fail2Ban is unavailable; run option 4 first.')"
          continue
        fi
        if [ "${#jails[@]}" -eq 0 ]; then
          printf '%s\n' "$(ui_text '当前没有启用的 Jail。' 'No jails are currently enabled.')"
          continue
        fi
        printf '%s\n' "$(ui_text '选择 Jail：' 'Select a jail:')"
        for jail_index in "${!jails[@]}"; do printf '%2d) %s\n' "$((jail_index + 1))" "${jails[$jail_index]//[[:space:]]/}"; done
        read -r -p '> ' jail_index || return
        case "$jail_index" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
        if [ "$jail_index" -lt 1 ] || [ "$jail_index" -gt "${#jails[@]}" ]; then printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue; fi
        jail=${jails[$((jail_index - 1))]}
        jail=${jail//[[:space:]]/}
        if [ "$choice" = 1 ]; then
          fail2ban-client status "$jail" || true
          fail2ban-client get "$jail" banip 2>/dev/null || true
        else
          read -r -p "$(ui_text '输入需要解封的 IP：' 'IP address to unban: ')" ip
          case "$ip" in ''|*[!0-9a-fA-F:.]*) printf '%s\n' "$(ui_text 'IP 格式无效。' 'Invalid IP format.')"; continue ;; esac
          case "$ip" in *.*|*:* ) ;; *) printf '%s\n' "$(ui_text 'IP 格式无效。' 'Invalid IP format.')"; continue ;; esac
          printf '%s\n' "$(ui_text "将从 $jail 解封 $ip。" "About to unban $ip from $jail.")"
          read -r -p "$(ui_text '确认解封？输入 y/n：' 'Confirm unban? Enter y/n: ')" confirm
          is_yes "$confirm" || { say cancel; continue; }
          fail2ban-client set "$jail" unbanip "$ip" || printf '%s\n' "$(ui_text '解封失败。' 'Unban failed.')"
        fi
        ;;
      3)
        if have journalctl; then journalctl -u fail2ban --no-pager -n 80; else printf '%s\n' "$(ui_text 'journalctl 不可用。' 'journalctl is unavailable.')"; fi
        ui_pause
        ;;
      4)
        if ! root_required || ! have apt-get; then continue; fi
        printf '%s\n' \
          "1) $(ui_text '安装/确保已安装' 'Install/ensure installed')" \
          "2) $(ui_text '仅更新已安装版本' 'Upgrade installed package only')" \
          "0) $(ui_text '返回' 'Back')"
        read -r -p '> ' package_action || return
        case "$package_action" in
          1) package_action=install ;;
          2) package_action=upgrade ;;
          0) continue ;;
          *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
        esac
        printf '%s\n' "$(ui_text '将先更新软件索引，然后执行所选的 Fail2Ban 软件包操作。' 'The package index will be refreshed, then the selected Fail2Ban package action will run.')"
        read -r -p "$(ui_text '确认安装/更新？输入 y/n：' 'Confirm install/update? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        package_ok=0
        if apt-get update; then
          if [ "$package_action" = install ] && apt-get install -y fail2ban; then
            package_ok=1
          elif [ "$package_action" = upgrade ] && apt-get install --only-upgrade -y fail2ban; then
            package_ok=1
          fi
        fi
        if [ "$package_ok" -eq 1 ]; then
          systemctl enable --now fail2ban 2>/dev/null || true
          printf '%s\n' "$(ui_text 'Fail2Ban 安装/更新完成；已尝试启用并启动服务。' 'Fail2Ban install/update completed; the service was enabled and started when possible.')"
        else
          printf '%s\n' "$(ui_text 'Fail2Ban 安装/更新失败，请检查上方 APT 输出。' 'Fail2Ban install/update failed; review the APT output above.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
