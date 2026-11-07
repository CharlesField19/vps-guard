#!/usr/bin/env bash

ui_logs_menu() {
  local choice lines
  while true; do
    printf '\n%s\n' "$(ui_text '日志查看（只读，不写文件）' 'Log viewer (read-only, no files written)')"
    printf '%s\n' \
      "1) $(ui_text 'SSH 登录日志' 'SSH login log')" \
      "2) $(ui_text 'Fail2Ban 日志' 'Fail2Ban log')" \
      "3) $(ui_text 'UFW 拒绝日志' 'UFW denied log')" \
      "4) $(ui_text '服务错误日志' 'Service error log')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    [ "$choice" = 0 ] && return
    read -r -p "$(ui_text '显示最近多少行（默认 80）：' 'How many recent lines (default 80): ')" lines
    [ -n "$lines" ] || lines=80
    case "$lines" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '行数无效。' 'Invalid line count.')"; continue ;; esac
    [ "$lines" -gt 500 ] && lines=500
    if ! have journalctl; then printf '%s\n' "$(ui_text 'journalctl 不可用。' 'journalctl is unavailable.')"; continue; fi
    case "$choice" in
      1) journalctl -u ssh -u sshd --no-pager -n "$lines" ;;
      2) journalctl -u fail2ban --no-pager -n "$lines" ;;
      3) journalctl -k --no-pager -n "$lines" --grep='UFW|BLOCK|DENY' || true ;;
      4) journalctl -p err..alert --no-pager -n "$lines" ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
    esac
    ui_pause
  done
}
ui_listening_ports() {
  local listeners
  printf '\n%s\n' "$(ui_text '监听端口（TCP/UDP，含地址族、绑定地址和进程）' 'Listening ports (TCP/UDP, address family, bind address and process)')"
  if ! have ss; then
    printf '%s\n' "$(ui_text '未安装 ss 命令，无法读取监听端口。' 'The ss command is unavailable; cannot inspect listeners.')"
    return 1
  fi
  listeners=$(ss -H -tulpen 2>/dev/null) || { printf '%s\n' "$(ui_text '读取监听端口失败。' 'Failed to read listening ports.')"; return 1; }
  if [ -z "$listeners" ]; then
    printf '%s\n' "$(ui_text '当前没有监听端口。' 'No listening ports found.')"
    return 0
  fi
  printf '%s\n' "$listeners" | awk '
    {
      local_addr = $5
      if (local_addr ~ /^0\.0\.0\.0:/ || local_addr ~ /^\*:|^\[::\]:|^:::/) scope = "ALL-INTERFACES"
      else if (local_addr ~ /^127\./ || local_addr ~ /^\[::1\]:|^::1:/) scope = "LOOPBACK"
      else scope = "SPECIFIC-IP"
      printf "[%s] %s\n", scope, $0
    }
  '
  printf '%s\n' "$(ui_text 'ALL-INTERFACES 表示绑定所有本机地址，可能可从公网访问；仍需检查 UFW、云安全组和服务自身认证。' 'ALL-INTERFACES means bound to all local addresses and may be reachable publicly; also check UFW, cloud security groups and service authentication.')"
}
