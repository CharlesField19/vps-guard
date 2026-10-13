#!/usr/bin/env bash

ui_text() {
  local zh=$1 en=$2
  if [ "${LANGUAGE:-zh}" = en ]; then printf '%s' "$en"; else printf '%s' "$zh"; fi
}

ui_pause() {
  read -r -p "$(ui_text '按回车返回主菜单...' 'Press Enter to return to the main menu...')" _
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
      0) return 0 ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; sleep 1 ;;
    esac
  done
}

ui_ipv6_status() {
  printf '\n%s\n' "$(ui_text 'IPv6 状态（只读检查）' 'IPv6 status (read-only)')"
  if [ -r /proc/net/if_inet6 ]; then
    cat /proc/net/if_inet6
    printf '%s\n' "$(ui_text '存在 IPv6 接口记录；这不代表公网 IPv6 一定可达。' 'IPv6 interface records exist; this does not guarantee public IPv6 connectivity.')"
  else
    printf '%s\n' "$(ui_text '未发现 IPv6 接口记录。' 'No IPv6 interface records found.')"
  fi
  have sysctl && sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 2>/dev/null || true
  [ -r /etc/default/ufw ] && grep -E '^[[:space:]]*IPV6=' /etc/default/ufw || true
}

ui_ipv6_menu() {
  local choice confirm
  while true; do
    ui_ipv6_status
    printf '%s\n' "1) $(ui_text '启用 IPv6 支持（需确认）' 'Enable IPv6 support (confirmation required)')" "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        printf '%s\n' "$(ui_text '这只启用本机 IPv6 和 UFW IPv6 支持；云厂商必须同时提供 IPv6 网络。' 'This enables local IPv6 and UFW IPv6 support; the cloud provider must also provide IPv6 networking.')"
        read -r -p "$(ui_text '输入 APPLY-IPV6 继续：' 'Type APPLY-IPV6 to continue: ')" confirm
        [ "$confirm" = APPLY-IPV6 ] || { say cancel; continue; }
        root_required || continue
        if ! backup_begin || ! backup_file /etc/default/ufw || ! backup_file /etc/sysctl.d/99-vps-guard-ipv6.conf; then
          continue
        fi
        mkdir -p /etc/sysctl.d
        cat > /etc/sysctl.d/99-vps-guard-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
EOF
        if [ -f /etc/default/ufw ]; then
          sed -i -E 's/^[[:space:]]*IPV6=.*/IPV6=yes/' /etc/default/ufw
          grep -q '^IPV6=' /etc/default/ufw || printf '\nIPV6=yes\n' >> /etc/default/ufw
        fi
        if sysctl --system >/dev/null 2>&1 && [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" = 0 ]; then
          printf '%s\n' "$(ui_text 'IPv6 配置已应用。请另外确认云厂商 IPv6 和安全组设置。' 'IPv6 configuration applied. Also verify the cloud IPv6 and security-group settings.')"
        else
          say rollback; rollback_latest; rm -f /etc/sysctl.d/99-vps-guard-ipv6.conf
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_bbr_status() {
  printf '\n%s\n' "$(ui_text 'BBR / fq 状态（只读检查）' 'BBR / fq status (read-only)')"
  if have sysctl; then
    sysctl net.ipv4.tcp_congestion_control net.ipv4.tcp_available_congestion_control net.core.default_qdisc 2>/dev/null || true
  else
    printf '%s\n' "$(ui_text 'sysctl 命令不可用。' 'sysctl command is unavailable.')"
  fi
}

ui_bbr_menu() {
  local choice confirm available
  while true; do
    ui_bbr_status
    printf '%s\n' "1) $(ui_text '启用 BBR + fq（需确认）' 'Enable BBR + fq (confirmation required)')" "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        available=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)
        case " $available " in *' bbr '*) ;; *) printf '%s\n' "$(ui_text '当前内核不报告 BBR 可用，未修改配置。' 'The current kernel does not report BBR as available; no changes made.')"; ui_pause; continue ;; esac
        read -r -p "$(ui_text '输入 APPLY-BBR 继续：' 'Type APPLY-BBR to continue: ')" confirm
        [ "$confirm" = APPLY-BBR ] || { say cancel; continue; }
        root_required || continue
         if ! backup_begin || ! backup_file /etc/sysctl.d/99-vps-guard-network.conf; then
           continue
         fi
         mkdir -p /etc/sysctl.d
         cat > /etc/sysctl.d/99-vps-guard-network.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        if sysctl --system >/dev/null 2>&1 && [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = bbr ] && [ "$(sysctl -n net.core.default_qdisc 2>/dev/null)" = fq ]; then
          printf '%s\n' "$(ui_text 'BBR + fq 已启用并验证。' 'BBR + fq enabled and verified.')"
        else
          say rollback; rollback_latest; rm -f /etc/sysctl.d/99-vps-guard-network.conf
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_ssh_firewall_menu() {
  local choice
  while true; do
    printf '\n%s\n' "$(ui_text 'SSH / 防火墙' 'SSH / Firewall')"
    printf '%s\n' \
      "1) $(ui_text '查看当前状态（只读）' 'View current status (read-only)')" \
      "2) $(ui_text '准备并应用 SSH 20001 + 防火墙基础规则' 'Apply SSH 20001 + basic firewall rules')" \
      "3) $(ui_text '回滚最近一次配置备份' 'Rollback latest configuration backup')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1) audit_ssh; audit_network; ui_pause ;;
      2) ui_apply_ssh_firewall; ui_pause ;;
      3) rollback; ui_pause ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_apply_ssh_firewall() {
  if ! root_required; then return 1; fi
  if ! have sshd; then
    printf '%s\n' "$(ui_text '未发现 sshd，无法修改 SSH。' 'sshd was not found; SSH cannot be changed.')"
    return 1
  fi
  if ! have ufw; then
    printf '%s\n' "$(ui_text '未安装 UFW；本功能不会自动安装软件。' 'UFW is not installed; this function will not install software.')"
    return 1
  fi

  printf '\n%s\n' "$(ui_text '将执行：允许 20001、80、443；设置 UFW 入站默认拒绝、出站允许；将 SSH 监听端口设为 20001。' 'Planned: allow 20001, 80 and 443; set UFW default incoming deny and outgoing allow; set SSH to listen on port 20001.')"
  printf '%s\n' "$(ui_text '旧 SSH 端口规则不会在本次操作中删除。请从第二个终端验证 20001 登录成功后，再手动清理旧规则。' 'The old SSH port rule will not be removed in this operation. Verify port 20001 from a second terminal before cleaning up the old rule.')"
  printf '%s\n' "$(ui_text '风险：高；可能影响远程访问。确认 VPS 控制台/救援入口可用。' 'Risk: HIGH; remote access may be affected. Confirm that a VPS console/rescue path is available.')"
  read -r -p "$(ui_text '输入 APPLY-SSH-FIREWALL 继续：' 'Type APPLY-SSH-FIREWALL to continue: ')" confirm
  [ "$confirm" = APPLY-SSH-FIREWALL ] || { printf '%s\n' "$(msg cancel)"; return 1; }

  backup_begin || return 1
  backup_file /etc/ssh/sshd_config || return 1
  backup_file /etc/default/ufw || return 1
  backup_file /etc/ufw/user.rules || return 1
  backup_file /etc/ufw/user6.rules || return 1
  say backup

  if ! ufw allow 20001/tcp || ! ufw allow 80/tcp || ! ufw allow 443/tcp; then
    say rollback; rollback_latest; return 1
  fi
  ufw default deny incoming || { say rollback; rollback_latest; return 1; }
  ufw default allow outgoing || { say rollback; rollback_latest; return 1; }
  if [ -f /etc/default/ufw ]; then
    sed -i -E 's/^[[:space:]]*IPV6=.*/IPV6=yes/' /etc/default/ufw
    grep -q '^IPV6=' /etc/default/ufw || printf '\nIPV6=yes\n' >> /etc/default/ufw
  fi

  sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' /etc/ssh/sshd_config
  printf '\nPort 20001\n' >> /etc/ssh/sshd_config
  if ! sshd -t 2>/dev/null || ! sshd -T 2>/dev/null | grep -qx 'port 20001'; then
    say rollback; rollback_latest; return 1
  fi
  if ! systemctl reload ssh 2>/dev/null && ! systemctl reload sshd 2>/dev/null; then
    say rollback; rollback_latest; return 1
  fi
  ufw --force enable || { say rollback; rollback_latest; return 1; }
  printf '%s\n' "$(ui_text '已应用。请立即从第二个终端测试：ssh -p 20001 用户@服务器。确认成功后，再清理旧 SSH 端口规则。' 'Applied. Immediately test from a second terminal: ssh -p 20001 user@server. After it succeeds, clean up the old SSH port rule.')"
}

ui_update_menu() {
  printf '\n%s\n' "$(ui_text '软件与内核更新' 'Software and kernel updates')"
  if ! have apt-get || ! have apt-cache; then
    printf '%s\n' "$(ui_text '当前仅支持使用 APT 的 Debian/Ubuntu 系统。' 'This option currently supports Debian/Ubuntu systems using APT only.')"
    ui_pause
    return
  fi

  printf '%s\n' "$(ui_text '以下为基于本机软件包索引的更新预览；此预览不会联网或安装软件。' 'The following preview uses the local package index; it does not access the network or install packages.')"
  apt-get -s full-upgrade 2>/dev/null || true
  printf '%s\n' "$(ui_text '注意：完整升级可能新增或移除软件包；请先检查上方模拟结果。' 'Note: a full upgrade may add or remove packages; review the simulation above first.')"
   printf '\n%s\n' "$(ui_text '现在执行 apt-get update 和 apt-get full-upgrade？系统不会自动重启。' 'Run apt-get update and apt-get full-upgrade now? The system will not reboot automatically.')"
  printf '%s\n' "$(ui_text '1) 是，开始更新' '1) Yes, start updates')"
  printf '%s\n' "$(ui_text '0) 否，返回主菜单' '0) No, return to main menu')"
  local answer
  read -r -p '> ' answer || return
  case "$answer" in
    1)
      if ! root_required; then ui_pause; return; fi
      printf '%s\n' "$(ui_text '开始更新软件和内核。更新过程可能需要一些时间；不会自动重启。' 'Updating software and kernel packages. This may take a while; no automatic reboot will occur.')"
      if apt-get update && DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y; then
        printf '%s\n' "$(ui_text '更新完成。请检查是否需要在维护时间手动重启。' 'Updates completed. Check whether a manual reboot is needed during a maintenance window.')"
        [ -e /var/run/reboot-required ] && printf '%s\n' "$(ui_text '系统提示需要重启。' 'The system indicates that a reboot is required.')"
      else
        printf '%s\n' "$(ui_text '更新失败或未完整完成；请检查上方 APT 输出。' 'Update failed or did not complete; review the APT output above.')"
      fi
      ui_pause
      ;;
    0) return ;;
    *) printf '%s\n' "$(ui_text '无效选择，未执行更新。' 'Invalid choice; no updates were run.')"; ui_pause ;;
  esac
}
