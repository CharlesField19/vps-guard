#!/usr/bin/env bash

ui_ssh_firewall_menu() {
  local choice
  while true; do
    printf '\n%s\n' "$(ui_text 'SSH / 防火墙' 'SSH / Firewall')"
    printf '%s\n' \
      "1) $(ui_text '查看当前状态（只读）' 'View current status (read-only)')" \
      "2) $(ui_text 'SSH 端口与 socket 管理' 'SSH port and socket management')" \
      "3) $(ui_text '应用 SSH 20001 + 防火墙基础规则' 'Apply SSH 20001 + basic firewall rules')" \
      "4) $(ui_text '管理 UFW 端口规则' 'Manage UFW rules')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1) audit_ssh; audit_network; ui_pause ;;
      2) ui_ssh_port_menu ;;
      3) ui_apply_ssh_firewall; ui_pause ;;
      4) ui_ufw_rules_menu ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
ui_ssh_port_status() {
  # Show both parsed sshd configuration and live listeners. On systems using
  # socket activation, the socket unit can keep listening on a different port.
  printf '\n%s\n' "$(ui_text 'SSH 有效端口配置：' 'Effective SSH port configuration:')"
  if have sshd; then sshd_effective_config | grep '^port ' || true; else printf '%s\n' 'sshd unavailable / 未发现 sshd'; fi
  if have systemctl; then
    printf '%s\n' "$(ui_text 'ssh.socket 状态：' 'ssh.socket status:')"
    systemctl is-active ssh.socket 2>/dev/null || true
    systemctl show --property=Listen --value ssh.socket 2>/dev/null || true
  fi
  printf '%s\n' "$(ui_text '实际 TCP 监听：' 'Actual TCP listeners:')"
  if have ss; then ss -lntp 2>/dev/null | awk 'NR == 1 || /sshd|systemd.*fd=/' ; else printf '%s\n' 'ss unavailable / 未发现 ss'; fi
}
ui_ssh_port_menu() {
  local choice port confirm
  while true; do
    ui_ssh_port_status
    printf '%s\n' \
      "1) $(ui_text '设置 SSH 端口（保留 22 并增加新端口）' 'Set SSH port (keep 22 and add the new port)')" \
      "0) $(ui_text '返回' 'Back')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        if ! root_required || ! have sshd || ! have systemctl || ! have ss; then
          printf '%s\n' "$(ui_text '需要 root、sshd、systemd 和 ss；未修改配置。' 'Root, sshd, systemd and ss are required; no configuration changed.')"
          continue
        fi
        read -r -p "$(ui_text '输入新 SSH 端口（1-65535）：' 'New SSH port (1-65535): ')" port
        case "$port" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '端口号无效。' 'Invalid port number.')"; continue ;; esac
        if [ "${#port}" -gt 5 ]; then
          printf '%s\n' "$(ui_text '端口号必须在 1-65535 之间。' 'Port must be between 1 and 65535.')"
          continue
        fi
        port=$((10#$port))
        if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
          printf '%s\n' "$(ui_text '端口号必须在 1-65535 之间。' 'Port must be between 1 and 65535.')"
          continue
        fi
        if [ "$port" = 22 ]; then
          printf '%s\n' "$(ui_text '端口 22 已是当前默认端口，无需添加。' 'Port 22 is already the default port; no change needed.')"
          continue
        fi
        printf '%s\n' "$(ui_text '操作会先放行新端口，并保留 22 以便测试；不会自动关闭 22。' 'The new port will be allowed and 22 will be kept for testing; port 22 will not be closed automatically.')"
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }

        ssh_change_port "$port"
        if [ "$SSH_CHANGE_UFW_MISSING" -eq 1 ]; then
          printf '%s\n' "$(ui_text '未安装 UFW，防火墙规则未修改。' 'UFW is not installed; firewall rules were not changed.')"
        fi
        if [ "$SSH_CHANGE_IPV6_DISABLED" -eq 1 ]; then
          printf '%s\n' "$(ui_text 'IPv6 不可用，socket 只绑定 IPv4。' 'IPv6 is unavailable; the socket will bind IPv4 only.')"
        fi
        case "$SSH_CHANGE_RESULT" in
          ok)
            printf '%s\n' "$(ui_text '新端口正在监听，22 仍保留。请另开终端测试登录；确认成功后再考虑移除旧防火墙规则。' 'The new port is listening and port 22 is still open. Test from another terminal before removing old firewall rules.')"
            ;;
          no_new_port)
            printf '%s\n' "$(ui_text '22 仍在监听，但未检测到新端口。请勿断开当前会话并检查 ssh.socket/SSH 状态。' 'Port 22 is still listening, but the new port was not detected. Keep this session open and inspect ssh.socket/SSH status.')"
            ;;
          custom_socket_dropin)
            printf '%s\n' "$(ui_text '检测到自定义 ssh.socket drop-in；为避免覆盖现有设置，未修改。' 'A custom ssh.socket drop-in was found; no changes made to avoid overwriting it.')"
            ;;
          unmanaged_socket_dropin)
            printf '%s\n' "$(ui_text '管理器目标配置文件已存在且不是本工具创建；未覆盖。' 'The target drop-in exists and is not managed by VPS Guard; it was not overwritten.')"
            ;;
          ufw_failed)
            printf '%s\n' "$(ui_text '放行 22 或新端口失败；未继续改 SSH。' 'Failed to allow port 22 or the new port; SSH was not changed.')"
            ;;
          backup_failed)
            printf '%s\n' "$(ui_text '无法创建备份，未修改 SSH。' 'Unable to create a backup; SSH was not changed.')"
            ;;
          write_failed)
            printf '%s\n' "$(ui_text '写入 SSH 端口失败，已恢复配置。' 'Failed to write the SSH ports; configuration was restored.')"
            ;;
          validate_failed)
            printf '%s\n' "$(ui_text 'SSH 配置验证失败，已恢复配置，未重载服务。' 'SSH configuration validation failed; configuration was restored and the service was not reloaded.')"
            ;;
          socket_failed)
            printf '%s\n' "$(ui_text '重启 ssh.socket 失败，已回滚 SSH 和 socket 配置。请勿断开当前会话。' 'Failed to restart ssh.socket; SSH and socket configuration were rolled back. Do not disconnect this session.')"
            ;;
          reload_failed)
            printf '%s\n' "$(ui_text '重载 SSH 失败，已恢复配置。请勿断开当前会话。' 'Failed to reload SSH; configuration was restored. Do not disconnect this session.')"
            ;;
          no22)
            printf '%s\n' "$(ui_text '22 端口不再监听，已回滚。请勿断开当前会话。' 'Port 22 is no longer listening; changes were rolled back. Do not disconnect this session.')"
            ;;
          *)
            printf '%s\n' "$(ui_text 'SSH 端口操作未完成；请检查服务状态。' 'The SSH port operation did not complete; check the service status.')"
            ;;
        esac
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_apply_ssh_firewall() {
  local confirm
  if ! root_required; then return 1; fi
  if ! have sshd; then
    printf '%s\n' "$(ui_text '未发现 sshd，无法修改 SSH。' 'sshd was not found; SSH cannot be changed.')"
    return 1
  fi
  if ! have ufw; then
    printf '%s\n' "$(ui_text '未安装 UFW；本功能不会自动安装软件。' 'UFW is not installed; this function will not install software.')"
    return 1
  fi
  if have systemctl && systemctl is-active --quiet ssh.socket 2>/dev/null; then
    printf '%s\n' "$(ui_text '检测到 ssh.socket 正在监听。请先使用本菜单的“SSH 端口与 socket 管理”设置端口，避免只修改 sshd_config 而实际监听不变。' 'ssh.socket is active. Use “SSH port and socket management” first; changing only sshd_config would not change the actual listener.')"
    return 1
  fi

  printf '%s\n' "$(ui_text '此快捷设置会先放行当前 SSH 端口以及 20001/80/443，确认 20001 已监听后，再设置 UFW 入站默认拒绝、出站允许并启用 UFW，同时把 SSH 端口设为 20001。它不删除旧的放行规则。验证、重载或监听检查失败会回滚 SSH 配置；默认策略修改失败会恢复原策略。' 'This shortcut first allows the current SSH port plus 20001/80/443, switches SSH to 20001, and only then sets UFW incoming deny/outgoing allow and enables UFW. Old allow rules are not removed. SSH configuration is restored if validation, reload, or the listener check fails; UFW defaults are restored if changing them fails.')"
  printf '\n%s\n' "$(ui_text '将执行：先放行当前 SSH 端口、20001、80、443；确认 20001 监听后，再设置 UFW 入站默认拒绝、出站允许，并将 SSH 端口设为 20001。' 'Planned: allow the current SSH port, 20001, 80 and 443 first; after port 20001 is listening, set UFW default incoming deny and outgoing allow, and set SSH to port 20001.')"
  printf '%s\n' "$(ui_text '旧 SSH 端口规则不会在本次操作中删除。请从第二个终端验证 20001 登录成功后，再手动清理旧规则。' 'The old SSH port rule will not be removed in this operation. Verify port 20001 from a second terminal before cleaning up the old rule.')"
  printf '%s\n' "$(ui_text '风险：高；可能影响远程访问。确认 VPS 控制台/救援入口可用。' 'Risk: HIGH; remote access may be affected. Confirm that a VPS console/rescue path is available.')"
  read -r -p "$(ui_text '确认应用？输入 y/n：' 'Confirm apply? Enter y/n: ')" confirm
  is_yes "$confirm" || { printf '%s\n' "$(msg cancel)"; return 1; }

  ssh_shortcut
  case "$SSH_CHANGE_RESULT" in
    ok)
      printf '%s\n' "$(ui_text '已应用。请立即从第二个终端测试：ssh -p 20001 用户@服务器。确认成功后再清理旧 SSH 端口规则。' 'Applied. Immediately test from a second terminal: ssh -p 20001 user@server. After it succeeds, clean up the old SSH port rule.')"
      ;;
    ufw_allow_failed)
      printf '%s\n' "$(ui_text 'UFW 放行失败；尚未修改 SSH 或默认策略。已添加的放行规则会保留。' 'Failed to add a UFW allow rule; SSH and the default policy were not changed. Allow rules already added are kept.')"
      ;;
    backup_failed)
      printf '%s\n' "$(ui_text '无法备份 SSH 配置，未修改 SSH。' 'Unable to back up SSH configuration; SSH was not changed.')"
      ;;
    dropin_failed)
      printf '%s\n' "$(ui_text '修改 SSH drop-in 失败，已恢复配置。' 'Failed to update the SSH drop-in; configuration was restored.')"
      ;;
    main_failed)
      printf '%s\n' "$(ui_text '修改 sshd_config 失败，已恢复配置。' 'Failed to update sshd_config; configuration was restored.')"
      ;;
    validate_failed)
      printf '%s\n' "$(ui_text 'SSH 配置验证失败，已恢复配置，未重载服务。' 'SSH configuration validation failed; configuration was restored and the service was not reloaded.')"
      ;;
    reload_failed)
      printf '%s\n' "$(ui_text '重载 SSH 失败，已恢复配置。请勿断开当前会话。' 'Failed to reload SSH; configuration was restored. Do not disconnect this session.')"
      ;;
    no20001)
      printf '%s\n' "$(ui_text '未检测到 20001 监听，已恢复 SSH 配置。请勿断开当前会话。' 'Port 20001 is not listening; SSH configuration was restored. Do not disconnect this session.')"
      ;;
    ufw_policy_failed)
      printf '%s\n' "$(ui_text 'UFW 默认策略或启用失败，已恢复原策略。SSH 已切到 20001；请从第二个终端确认登录。' 'Failed to update or enable UFW defaults; the previous policy was restored. SSH is already on port 20001; confirm login from a second terminal.')"
      ;;
    socket_active|no_sshd|no_ufw|not_root)
      printf '%s\n' "$(ui_text '当前环境不满足快捷设置条件；未修改系统。' 'The current environment does not meet the shortcut requirements; no changes were made.')"
      ;;
    *)
      printf '%s\n' "$(ui_text '快捷设置未完成；请检查服务状态。' 'The shortcut did not complete; check the service status.')"
      ;;
  esac
  [ "$SSH_CHANGE_RESULT" = ok ] && return 0
  return 1
}
