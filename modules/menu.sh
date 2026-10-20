#!/usr/bin/env bash

ui_text() {
  local zh=$1 en=$2
  if [ "${LANGUAGE:-zh}" = en ]; then printf '%s' "$en"; else printf '%s' "$zh"; fi
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
        read -r -p "$(ui_text '输入 APPLY 继续：' 'Type APPLY to continue: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        root_required || continue
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
          printf '%s\n' "$(ui_text 'IPv6 验证失败；未自动回滚配置。请检查 /etc/sysctl.d/99-vps-guard-ipv6.conf 和 /etc/default/ufw。' 'IPv6 validation failed; configuration was not automatically reverted. Check /etc/sysctl.d/99-vps-guard-ipv6.conf and /etc/default/ufw.')"
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
        read -r -p "$(ui_text '输入 APPLY 继续：' 'Type APPLY to continue: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
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

ui_ssh_firewall_menu() {
  local choice
  while true; do
    printf '\n%s\n' "$(ui_text 'SSH / 防火墙' 'SSH / Firewall')"
    printf '%s\n' \
      "1) $(ui_text '查看当前状态（只读）' 'View current status (read-only)')" \
      "2) $(ui_text '准备并应用 SSH 20001 + 防火墙基础规则' 'Apply SSH 20001 + basic firewall rules')" \
      "3) $(ui_text '管理 UFW 端口规则（新增 / 删除）' 'Manage UFW port rules (add / delete)')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1) audit_ssh; audit_network; ui_pause ;;
      2) ui_apply_ssh_firewall; ui_pause ;;
      3) ui_ufw_rules_menu ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_ufw_rules_menu() {
  local choice protocol port confirm rules rule_no
  if ! root_required; then return 1; fi
  if ! have ufw; then
    printf '%s\n' "$(ui_text '未安装 UFW。' 'UFW is not installed.')"
    ui_pause
    return 1
  fi

  while true; do
    printf '\n%s\n' "$(ui_text 'UFW 端口规则管理' 'UFW port rules')"
    printf '%s\n' \
      "1) $(ui_text '新增端口放行规则' 'Add an allow rule')" \
      "2) $(ui_text '查看并删除现有规则' 'List and delete an existing rule')" \
      "0) $(ui_text '返回' 'Back')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        read -r -p "$(ui_text '输入端口号（1-65535）：' 'Port number (1-65535): ')" port
        case "$port" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '端口号无效。' 'Invalid port number.')"; continue ;; esac
        if [ "${#port}" -gt 5 ]; then
          printf '%s\n' "$(ui_text '端口号必须在 1-65535 之间。' 'Port must be between 1 and 65535.')"
          continue
        fi
        if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
          printf '%s\n' "$(ui_text '端口号必须在 1-65535 之间。' 'Port must be between 1 and 65535.')"
          continue
        fi
        printf '%s\n' \
          "1) TCP" \
          "2) UDP" \
          "3) TCP + UDP"
        read -r -p '> ' protocol || return
        case "$protocol" in
          1) protocol=tcp ;;
          2) protocol=udp ;;
          3) protocol=both ;;
          *) printf '%s\n' "$(ui_text '无效协议选择。' 'Invalid protocol choice.')"; continue ;;
        esac
        printf '%s\n' "$(ui_text "即将放行端口 $port/$protocol。" "About to allow port $port/$protocol.")"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if [ "$protocol" = both ]; then
          if ! ufw allow "$port/tcp" || ! ufw allow "$port/udp"; then
            printf '%s\n' "$(ui_text '添加规则失败；未自动回滚，可能已有部分规则生效。' 'Adding rules failed; no automatic rollback was performed, and a partial rule may have been applied.')"
          else
            printf '%s\n' "$(ui_text '规则已新增。' 'Rules added.')"
          fi
        elif ufw allow "$port/$protocol"; then
          printf '%s\n' "$(ui_text '规则已新增。' 'Rule added.')"
        else
          printf '%s\n' "$(ui_text '添加规则失败；未自动回滚。' 'Adding the rule failed; no automatic rollback was performed.')"
        fi
        ui_pause
        ;;
      2)
        rules=$(ufw status numbered 2>/dev/null) || { printf '%s\n' "$(ui_text '无法读取 UFW 规则。' 'Unable to read UFW rules.')"; continue; }
        printf '%s\n' "$rules"
        if ! printf '%s\n' "$rules" | grep -Eq '^\[[[:space:]]*[0-9]+\]'; then
          printf '%s\n' "$(ui_text '没有可删除的编号规则。' 'No numbered rules to delete.')"
          continue
        fi
        read -r -p "$(ui_text '输入要删除的规则编号（0 返回）：' 'Rule number to delete (0 to return): ')" rule_no
        [ "$rule_no" = 0 ] && continue
        case "$rule_no" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '编号无效。' 'Invalid rule number.')"; continue ;; esac
        if ! printf '%s\n' "$rules" | grep -Eq "^\\[[[:space:]]*$rule_no\\]"; then
          printf '%s\n' "$(ui_text '找不到该规则编号。' 'Rule number not found.')"
          continue
        fi
        read -r -p "$(ui_text '输入 APPLY 确认删除该规则：' 'Type APPLY to confirm deleting this rule: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if ufw --force delete "$rule_no"; then
          printf '%s\n' "$(ui_text '规则已删除。' 'Rule deleted.')"
        else
          printf '%s\n' "$(ui_text '删除规则失败；未执行自动回滚。' 'Deleting the rule failed; no automatic rollback was performed.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_apply_ssh_firewall() {
  local config_file effective_config
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
  read -r -p "$(ui_text '输入 APPLY 继续：' 'Type APPLY to continue: ')" confirm
  [ "$confirm" = APPLY ] || { printf '%s\n' "$(msg cancel)"; return 1; }

  if ! ufw allow 20001/tcp || ! ufw allow 80/tcp || ! ufw allow 443/tcp; then
    printf '%s\n' "$(ui_text 'UFW 规则设置失败；未自动回滚，请检查当前规则。' 'Failed to set UFW rules; no automatic rollback was performed. Check the current rules.')"
    return 1
  fi
  ufw default deny incoming || { printf '%s\n' "$(ui_text '设置 UFW 入站策略失败；未自动回滚。' 'Failed to set UFW incoming policy; no automatic rollback was performed.')"; return 1; }
  ufw default allow outgoing || { printf '%s\n' "$(ui_text '设置 UFW 出站策略失败；未自动回滚。' 'Failed to set UFW outgoing policy; no automatic rollback was performed.')"; return 1; }
  if [ -f /etc/default/ufw ]; then
    sed -i -E 's/^[[:space:]]*IPV6=.*/IPV6=yes/' /etc/default/ufw
    grep -q '^IPV6=' /etc/default/ufw || printf '\nIPV6=yes\n' >> /etc/default/ufw
  fi

  # OpenSSH uses the first value found. Port directives in included drop-ins
  # are read before directives later in sshd_config, so clear them too.
  if [ -d /etc/ssh/sshd_config.d ]; then
    while IFS= read -r -d '' config_file; do
      sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' "$config_file" || { printf '%s\n' "$(ui_text '修改 SSH drop-in 配置失败；未自动回滚。' 'Failed to update the SSH drop-in configuration; no automatic rollback was performed.')"; return 1; }
    done < <(find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -print0)
  fi
  sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' /etc/ssh/sshd_config
  printf '\nPort 20001\n' >> /etc/ssh/sshd_config
  effective_config=$(sshd -T 2>/dev/null) || { printf '%s\n' "$(ui_text '读取 SSH 生效配置失败；未自动回滚。' 'Failed to read effective SSH configuration; no automatic rollback was performed.')"; return 1; }
  if ! sshd -t 2>/dev/null || ! printf '%s\n' "$effective_config" | awk '$1 == "port" { count++; if ($2 != "20001") invalid=1 } END { exit !(count == 1 && !invalid) }'; then
    printf '%s\n' "$(ui_text 'SSH 配置验证失败；未自动回滚，请检查 SSH 配置。' 'SSH configuration validation failed; no automatic rollback was performed. Check SSH configuration.')"
    return 1
  fi
  if ! systemctl reload ssh 2>/dev/null && ! systemctl reload sshd 2>/dev/null; then
    printf '%s\n' "$(ui_text '重载 SSH 失败；未自动回滚，请检查 SSH 服务状态。' 'Failed to reload SSH; no automatic rollback was performed. Check the SSH service status.')"
    return 1
  fi
  ufw --force enable || { printf '%s\n' "$(ui_text '启用 UFW 失败；未自动回滚。' 'Failed to enable UFW; no automatic rollback was performed.')"; return 1; }
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
