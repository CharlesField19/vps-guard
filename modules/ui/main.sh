#!/usr/bin/env bash

ui_text() {
  local zh=$1 en=$2
  if [ "${VPS_GUARD_LANG:-zh}" = en ]; then printf '%s' "$en"; else printf '%s' "$zh"; fi
}
ui_pause() {
  printf '\n%s\n' "$(ui_text '操作完成。按回车返回主菜单；不会重新下载项目。' 'Operation complete. Press Enter to return to the main menu; the project will not be downloaded again.')"
  read -r -p '> ' _
}
ui_main_menu() {
  local choice
  while true; do
    clear 2>/dev/null || true
    printf '==== %s ====\n' "$(ui_text 'VPS Guard 基础初始化' 'VPS Guard Basic Setup')"
    printf '%s\n' \
      "1) $(ui_text 'VPS 信息审计（只读）' 'VPS information audit (read-only)')" \
      "2) $(ui_text 'SSH / 防火墙状态' 'SSH / firewall status')" \
      "3) $(ui_text 'IPv6 状态与配置' 'IPv6 status and configuration')" \
      "4) $(ui_text 'BBR / fq 状态与配置' 'BBR / fq status and configuration')" \
      "5) $(ui_text '软件与内核更新' 'Software and kernel updates')" \
      "6) $(ui_text '服务管理' 'Service management')" \
      "7) $(ui_text '监听端口检查' 'Listening port inspection')" \
      "8) $(ui_text 'Fail2Ban 管理' 'Fail2Ban management')" \
      "9) $(ui_text '用户与 SSH 密钥' 'Users and SSH keys')" \
      "10) $(ui_text '资源监控' 'Resource monitoring')" \
      "11) $(ui_text '日志查看' 'Log viewer')" \
      "12) $(ui_text 'Docker 管理' 'Docker management')" \
      "13) $(ui_text '定时任务管理' 'Scheduled task management')" \
      "14) $(ui_text '安全清理' 'Safe cleanup')" \
      "15) $(ui_text '网络安全检查' 'Network security check')" \
      "16) $(ui_text '配置状态导出到终端' 'Export configuration status to terminal')" \
      "17) $(ui_text '扩展诊断（磁盘/重启/HTTP/路由）' 'Extended diagnostics (disk/reboot/HTTP/route)')" \
      "0) $(ui_text '退出' 'Exit')"
    read -r -p '> ' choice || return 0

    case "$choice" in
      1)
        audit_all
        ui_pause
        ;;
      2)
        ui_ssh_firewall_menu
        ;;
      3)
        ui_ipv6_menu
        ;;
      4)
        ui_bbr_menu
        ;;
      5)
        ui_update_menu
        ;;
      6)
        ui_service_menu
        ;;
      7)
        ui_listening_ports
        ui_pause
        ;;
      8)
        ui_fail2ban_menu
        ;;
      9)
        ui_users_keys_menu
        ;;
      10)
        ui_resources_status
        ui_pause
        ;;
      11)
        ui_logs_menu
        ;;
      12)
        ui_docker_menu
        ;;
      13)
        ui_scheduled_menu
        ;;
      14)
        ui_cleanup_menu
        ;;
      15)
        ui_network_menu
        ui_pause
        ;;
      16)
        ui_export_status
        ui_pause
        ;;
      17)
        ui_extended_diagnostics
        ;;
      0) return 0 ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; sleep 1 ;;
    esac
  done
}
