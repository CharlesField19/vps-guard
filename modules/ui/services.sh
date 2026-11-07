#!/usr/bin/env bash

ui_service_menu() {
  local choice service action confirm state index
  local -a services=(ssh ssh.socket ufw fail2ban docker nginx cron apparmor auditd)
  if ! have systemctl; then
    printf '%s\n' "$(ui_text 'systemd/systemctl 不可用。' 'systemd/systemctl is unavailable.')"
    ui_pause
    return 1
  fi

  while true; do
    printf '\n%s\n' "$(ui_text '常用服务状态' 'Common service status')"
    for index in "${!services[@]}"; do
      service=${services[$index]}
      state=$(systemctl is-active "$service" 2>/dev/null || true)
      printf '%2d) %-12s %s\n' "$((index + 1))" "$service" "${state:-unknown}"
    done
    printf '%s\n' "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    [ "$choice" = 0 ] && return
    case "$choice" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#services[@]}" ]; then
      printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"
      continue
    fi
    service=${services[$((choice - 1))]}
    printf '\n%s\n' "$(ui_text "当前服务：$service" "Selected service: $service")"
    printf '%s\n' "$(ui_text '启动会启动服务；停止会中断服务；重启会先停止再启动；重载通常重新读取配置而不完全停止。服务不支持 reload 时该操作会失败。0 返回服务列表。' 'Start activates a service; stop interrupts it; restart stops then starts it; reload usually rereads configuration without a full stop. Unsupported reload actions fail. 0 returns to the service list.')"
    systemctl status --no-pager --lines=12 "$service" 2>&1 || true
    printf '%s\n' \
      "1) $(ui_text '仅查看状态' 'Show status only')" \
      "2) $(ui_text '启动' 'Start')" \
      "3) $(ui_text '停止' 'Stop')" \
      "4) $(ui_text '重启' 'Restart')" \
      "5) $(ui_text '重载' 'Reload')" \
      "0) $(ui_text '返回服务列表' 'Back to service list')"
    read -r -p '> ' action || return
    case "$action" in
      0|1) continue ;;
      2) action=start ;;
      3) action=stop ;;
      4) action=restart ;;
      5) action=reload ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
    esac
    if [ "$action" = stop ] && { [ "$service" = ssh ] || [ "$service" = ssh.socket ] || [ "$service" = ufw ]; }; then
      printf '%s\n' "$(ui_text '高风险：停止 SSH/UFW 可能导致远程失联或暴露服务。' 'High risk: stopping SSH/UFW may disconnect you or expose services.')"
    fi
    read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
    is_yes "$confirm" || { say cancel; continue; }
    if systemctl "$action" "$service"; then
      printf '%s\n' "$(ui_text '服务操作已完成。' 'Service action completed.')"
    else
      printf '%s\n' "$(ui_text '服务操作失败；请检查上方 systemd 输出。' 'Service action failed; review the systemd output above.')"
    fi
    ui_pause
  done
}
