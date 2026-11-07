#!/usr/bin/env bash

ui_ufw_rules_menu() {
  local choice protocol port confirm rules rule_no config_file
  local -a ufw_cmd
  if ! root_required; then return 1; fi
  if ! have ufw; then
    printf '%s\n' "$(ui_text '未安装 UFW。' 'UFW is not installed.')"
    ui_pause
    return 1
  fi

  while true; do
    printf '\n%s\n' "$(ui_text 'UFW 端口规则管理' 'UFW port rules')"
    printf '%s\n' "$(ui_text 'UFW 是 Linux 主机防火墙。新增规则只允许网络流量通过防火墙，不会启动对应应用；删除规则可能让远程服务无法访问。' 'UFW is the Linux host firewall. Adding a rule only permits traffic through the firewall; it does not start an application. Removing a rule can make a remote service unreachable.')"
    ufw status verbose 2>/dev/null || true
    printf '%s\n' \
      "1) $(ui_text '新增端口放行规则' 'Add an allow rule')" \
      "2) $(ui_text '查看并删除现有规则' 'List and delete an existing rule')" \
      "3) $(ui_text '启用 UFW' 'Enable UFW')" \
      "4) $(ui_text '禁用 UFW（高风险）' 'Disable UFW (high risk)')" \
      "5) $(ui_text '默认拒绝入站' 'Set default incoming deny')" \
      "6) $(ui_text '默认允许入站（高风险）' 'Set default incoming allow (high risk)')" \
      "7) $(ui_text '默认允许出站' 'Set default outgoing allow')" \
      "8) $(ui_text '默认拒绝出站' 'Set default outgoing deny')" \
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
        port=$((10#$port))
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
        read -r -p "$(ui_text '确认放行？输入 y/n：' 'Confirm allow? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
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
        printf '%s\n' "$(ui_text '删除规则前先核对编号、端口和协议；输入 0 返回，不会删除。确认处输入 y 执行，输入 n 取消。' 'Check the rule number, port and protocol before deleting; enter 0 to return without deleting. Enter y to confirm or n to cancel.')"
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
        read -r -p "$(ui_text '确认删除该规则？输入 y/n：' 'Confirm deleting this rule? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if ufw --force delete "$rule_no"; then
          printf '%s\n' "$(ui_text '规则已删除。' 'Rule deleted.')"
        else
          printf '%s\n' "$(ui_text '删除规则失败；未执行自动回滚。' 'Deleting the rule failed; no automatic rollback was performed.')"
        fi
        ui_pause
        ;;
      3|4|5|6|7|8)
        case "$choice" in
          3) ufw_cmd=(ufw --force enable) ;;
          4) ufw_cmd=(ufw --force disable) ;;
          5) ufw_cmd=(ufw default deny incoming) ;;
          6) ufw_cmd=(ufw default allow incoming) ;;
          7) ufw_cmd=(ufw default allow outgoing) ;;
          8) ufw_cmd=(ufw default deny outgoing) ;;
        esac
        if [ "$choice" = 4 ] || [ "$choice" = 6 ] || [ "$choice" = 8 ]; then
          printf '%s\n' "$(ui_text '警告：此操作可能暴露服务或中断 VPS 网络访问。' 'Warning: this may expose services or interrupt VPS network access.')"
        fi
        printf '%s\n' "$(ui_text '将执行所选 UFW 操作。' 'The selected UFW operation will be applied.')"
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if "${ufw_cmd[@]}"; then
          printf '%s\n' "$(ui_text 'UFW 设置已更新。' 'UFW setting updated.')"
        else
          printf '%s\n' "$(ui_text 'UFW 操作失败。' 'UFW operation failed.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
