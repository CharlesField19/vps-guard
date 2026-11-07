#!/usr/bin/env bash

ui_ipv6_status() {
  printf '\n%s\n' "$(ui_text 'IPv6 状态（只读检查）' 'IPv6 status (read-only)')"
  if [ -r /proc/net/if_inet6 ]; then
    cat /proc/net/if_inet6
    printf '%s\n' "$(ui_text '存在 IPv6 接口记录；这不代表公网 IPv6 一定可达。' 'IPv6 interface records exist; this does not guarantee public IPv6 connectivity.')"
  else
    printf '%s\n' "$(ui_text '未发现 IPv6 接口记录。' 'No IPv6 interface records found.')"
  fi
  have sysctl && sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 2>/dev/null || true
  [ -r "$VPS_GUARD_UFW_DEFAULTS" ] && grep -E '^[[:space:]]*IPV6=' "$VPS_GUARD_UFW_DEFAULTS" || true
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
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        root_required || continue
        mkdir -p /etc/sysctl.d
        cat > /etc/sysctl.d/99-vps-guard-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
EOF
        if [ -f "$VPS_GUARD_UFW_DEFAULTS" ]; then
          sed -i -E 's/^[[:space:]]*IPV6=.*/IPV6=yes/' "$VPS_GUARD_UFW_DEFAULTS"
          grep -q '^IPV6=' "$VPS_GUARD_UFW_DEFAULTS" || printf '\nIPV6=yes\n' >> "$VPS_GUARD_UFW_DEFAULTS"
        fi
        if sysctl --system >/dev/null 2>&1 && [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" = 0 ]; then
          printf '%s\n' "$(ui_text 'IPv6 配置已应用。请另外确认云厂商 IPv6 和安全组设置。' 'IPv6 configuration applied. Also verify the cloud IPv6 and security-group settings.')"
        else
          printf '%s\n' "$(ui_text "IPv6 验证失败；未自动回滚配置。请检查 /etc/sysctl.d/99-vps-guard-ipv6.conf 和 $VPS_GUARD_UFW_DEFAULTS。" "IPv6 validation failed; configuration was not automatically reverted. Check /etc/sysctl.d/99-vps-guard-ipv6.conf and $VPS_GUARD_UFW_DEFAULTS.")"
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
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        root_required || continue
        mkdir -p /etc/sysctl.d
         cat > /etc/sysctl.d/99-vps-guard-network.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        if sysctl --system >/dev/null 2>&1 && [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = bbr ] && [ "$(sysctl -n net.core.default_qdisc 2>/dev/null)" = fq ]; then
          printf '%s\n' "$(ui_text 'BBR + fq 已启用并验证。' 'BBR + fq enabled and verified.')"
        else
          printf '%s\n' "$(ui_text 'BBR 验证失败；未自动回滚配置。请检查 /etc/sysctl.d/99-vps-guard-network.conf。' 'BBR validation failed; configuration was not automatically reverted. Check /etc/sysctl.d/99-vps-guard-network.conf.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
ui_update_menu() {
  printf '\n%s\n' "$(ui_text '软件与内核更新' 'Software and kernel updates')"
  if ! have apt-get || ! have apt-cache; then
    printf '%s\n' "$(ui_text '当前仅支持使用 APT 的 Debian/Ubuntu 系统。' 'This option currently supports Debian/Ubuntu systems using APT only.')"
    ui_pause
    return
  fi

  printf '%s\n' "$(ui_text '以下为基于本机软件包索引的更新预览；此预览不会联网或安装软件。' 'The following preview uses the local package index; it does not access the network or install packages.')"
  apt-get -s upgrade 2>/dev/null || true
  printf '%s\n' "$(ui_text '请检查上方模拟结果；此操作不会执行可能移除软件包的 full-upgrade。' 'Review the simulation above; this will not run full-upgrade, which may remove packages.')"
  printf '\n%s\n' "$(ui_text '输入 y 执行 apt-get update 和 apt-get upgrade（系统不会自动重启）；输入 n 或 0 返回。' 'Type y to run apt-get update and apt-get upgrade (the system will not reboot automatically); type n or 0 to return.')"
  local answer
  read -r -p '> ' answer || return
  case "$answer" in
    [yY]|[yY][eE][sS])
      if ! root_required; then ui_pause; return; fi
      printf '%s\n' "$(ui_text '开始更新软件和内核。更新过程可能需要一些时间；不会自动重启。' 'Updating software and kernel packages. This may take a while; no automatic reboot will occur.')"
      if apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
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
ui_network_menu() {
  printf '\n%s\n' "$(ui_text '网络安全检查（只读）' 'Network security check (read-only)')"
  printf '%s\n' '--- addresses / 地址 ---'
  ip -brief address 2>/dev/null || true
  printf '%s\n' '--- routes / 路由 ---'
  ip route 2>/dev/null || true
  ip -6 route 2>/dev/null || true
  printf '%s\n' '--- DNS / DNS ---'
  resolvectl status 2>/dev/null || cat /etc/resolv.conf 2>/dev/null || true
  printf '%s\n' '--- public address (network dependent) / 公网地址（依赖网络） ---'
  if have curl; then curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null; printf '\n'; curl -6 -fsS --max-time 5 https://api6.ipify.org 2>/dev/null; printf '\n'; else printf '%s\n' 'curl unavailable / curl 不可用'; fi
  printf '%s\n' "$(ui_text '云厂商安全组无法由 VPS 内部可靠修改；请同时检查官网安全组，只开放必要端口。' 'Cloud security groups cannot be reliably changed from inside the VPS; check the provider console and allow only required ports.')"
}
