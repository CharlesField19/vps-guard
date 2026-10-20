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
        ;;
      16)
        ui_export_status
        ui_pause
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

ui_users_keys_menu() {
  local choice username key confirm add_to_sudo home user_group key_type key_data
  while true; do
    printf '\n%s\n' "$(ui_text '用户与 SSH 密钥' 'Users and SSH keys')"
    printf '%s\n' \
      "1) $(ui_text '列出用户和 sudo 组' 'List users and sudo group')" \
      "2) $(ui_text '创建普通用户' 'Create a normal user')" \
      "3) $(ui_text '为用户添加 SSH 公钥' 'Add an SSH public key')" \
      "4) $(ui_text '启用 root 公钥登录、关闭 root 密码登录' 'Disable root password login after key check')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        printf '%s\n' "$(ui_text '可登录用户：' 'Login-capable users:')"
        awk -F: '$7 !~ /(nologin|false)$/ {printf "%-20s uid=%s home=%s shell=%s\n", $1, $3, $6, $7}' /etc/passwd
        printf '%s\n' 'sudo:'; getent group sudo 2>/dev/null || true
        ui_pause
        ;;
      2)
        if ! root_required || ! have useradd; then continue; fi
        read -r -p "$(ui_text '输入新用户名：' 'New username: ')" username
        case "$username" in ''|*[!a-zA-Z0-9_-]*) printf '%s\n' "$(ui_text '用户名格式无效。' 'Invalid username.')"; continue ;; esac
        if id "$username" >/dev/null 2>&1; then printf '%s\n' "$(ui_text '用户已存在。' 'User already exists.')"; continue; fi
        read -r -p "$(ui_text '是否加入 sudo 组？输入 y 或 n：' 'Add to sudo group? Type y or n: ')" confirm
        case "$confirm" in y|Y) add_to_sudo=yes ;; n|N) add_to_sudo=no ;; *) printf '%s\n' "$(ui_text '请输入 y 或 n。' 'Please enter y or n.')"; continue ;; esac
        read -r -p "$(ui_text '输入 APPLY 创建用户：' 'Type APPLY to create the user: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if useradd -m -s /bin/bash "$username"; then
          if [ "$add_to_sudo" = yes ]; then
            if usermod -aG sudo "$username"; then
              printf '%s\n' "$(ui_text '用户已创建并加入 sudo 组。' 'User created and added to the sudo group.')"
            else
              printf '%s\n' "$(ui_text '用户已创建，但加入 sudo 组失败。' 'User created, but adding to sudo failed.')"
            fi
          else
            printf '%s\n' "$(ui_text '用户已创建；请使用 passwd 或 SSH 公钥设置登录方式。' 'User created; configure login with passwd or an SSH public key.')"
          fi
        else
          printf '%s\n' "$(ui_text '创建用户失败。' 'Failed to create user.')"
        fi
        ui_pause
        ;;
      3)
        if ! root_required; then continue; fi
        read -r -p "$(ui_text '目标用户名：' 'Target username: ')" username
        if ! id "$username" >/dev/null 2>&1; then printf '%s\n' "$(ui_text '用户不存在。' 'User does not exist.')"; continue; fi
        read -r -p "$(ui_text '粘贴一行 SSH 公钥：' 'Paste one SSH public key line: ')" key
        read -r key_type key_data _ <<< "$key"
        case "$key_type" in ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) ;; *) printf '%s\n' "$(ui_text '不支持或无效的公钥类型。' 'Unsupported or invalid public key type.')"; continue ;; esac
        if [ -z "$key_data" ] || ! [[ "$key_data" =~ ^[A-Za-z0-9+/]+={0,2}$ ]]; then printf '%s\n' "$(ui_text '公钥数据格式无效。' 'Invalid public key data.')"; continue; fi
        read -r -p "$(ui_text '输入 APPLY 写入公钥：' 'Type APPLY to write the key: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        home=$(getent passwd "$username" | cut -d: -f6)
        user_group=$(id -gn "$username")
        if [ -z "$home" ] || [ ! -d "$home" ]; then printf '%s\n' "$(ui_text '用户主目录不存在。' 'The user home directory does not exist.')"; continue; fi
        if install -d -m 700 -o "$username" -g "$user_group" "$home/.ssh" && printf '%s\n' "$key" >> "$home/.ssh/authorized_keys" && chown "$username:$user_group" "$home/.ssh/authorized_keys" && chmod 600 "$home/.ssh/authorized_keys"; then
          printf '%s\n' "$(ui_text '公钥已写入。' 'Public key added.')"
        else
          printf '%s\n' "$(ui_text '写入公钥失败；请检查主目录权限。' 'Failed to write the key; check home directory permissions.')"
        fi
        ui_pause
        ;;
      4)
        harden_ssh_root_password
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_resources_status() {
  printf '\n%s\n' "$(ui_text '资源监控（只读）' 'Resource monitoring (read-only)')"
  printf '%s\n' '--- load / 负载 ---'; uptime 2>/dev/null || true
  printf '%s\n' '--- memory / 内存 ---'; free -h 2>/dev/null || true
  printf '%s\n' '--- disks / 磁盘 ---'; df -hT 2>/dev/null || true
  printf '%s\n' '--- inode ---'; df -ih 2>/dev/null || true
  printf '%s\n' '--- top CPU processes / CPU 占用进程 ---'; ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 11 || true
  printf '%s\n' '--- top memory processes / 内存占用进程 ---'; ps -eo pid,user,%cpu,%mem,comm --sort=-%mem 2>/dev/null | head -n 11 || true
}

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
      3) journalctl -k --no-pager -n "$lines" | grep -iE 'UFW|BLOCK|DENY' || true ;;
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

ui_fail2ban_menu() {
  local choice status_text jail_index jail ip confirm jail_csv
  local -a jails=()
  if ! have fail2ban-client; then
    printf '%s\n' "$(ui_text '未安装 Fail2Ban 客户端。' 'Fail2Ban client is not installed.')"
    ui_pause
    return 1
  fi
  if ! fail2ban-client ping >/dev/null 2>&1; then
    printf '%s\n' "$(ui_text 'Fail2Ban 服务未运行或客户端无法连接。' 'Fail2Ban service is not running or the client cannot connect.')"
    ui_pause
    return 1
  fi
  status_text=$(fail2ban-client status 2>/dev/null) || { printf '%s\n' "$(ui_text '读取 Fail2Ban 状态失败。' 'Failed to read Fail2Ban status.')"; return 1; }
  printf '\n%s\n' "$status_text"
  jail_csv=$(printf '%s\n' "$status_text" | sed -n 's/^[[:space:]]*Jail list:[[:space:]]*//p' | tail -n 1)
  if [ -n "$jail_csv" ]; then
    IFS=',' read -r -a jails <<< "$jail_csv"
  fi
  while true; do
    printf '%s\n' \
      "1) $(ui_text '查看 Jail 状态和封禁 IP' 'View jail status and banned IPs')" \
      "2) $(ui_text '解封 IP' 'Unban an IP')" \
      "3) $(ui_text '查看 Fail2Ban 日志' 'View Fail2Ban logs')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1|2)
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
          read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
          [ "$confirm" = APPLY ] || { say cancel; continue; }
          fail2ban-client set "$jail" unbanip "$ip" || printf '%s\n' "$(ui_text '解封失败。' 'Unban failed.')"
        fi
        ;;
      3)
        if have journalctl; then journalctl -u fail2ban --no-pager -n 80; else printf '%s\n' "$(ui_text 'journalctl 不可用。' 'journalctl is unavailable.')"; fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

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
    read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
    [ "$confirm" = APPLY ] || { say cancel; continue; }
    if systemctl "$action" "$service"; then
      printf '%s\n' "$(ui_text '服务操作已完成。' 'Service action completed.')"
    else
      printf '%s\n' "$(ui_text '服务操作失败；请检查上方 systemd 输出。' 'Service action failed; review the systemd output above.')"
    fi
    ui_pause
  done
}

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
  printf '\n%s\n' "$(ui_text 'SSH 有效端口配置：' 'Effective SSH port configuration:')"
  if have sshd; then sshd -T 2>/dev/null | grep '^port ' || true; else printf '%s\n' 'sshd unavailable / 未发现 sshd'; fi
  if have systemctl; then
    printf '%s\n' "$(ui_text 'ssh.socket 状态：' 'ssh.socket status:')"
    systemctl is-active ssh.socket 2>/dev/null || true
    systemctl show --property=Listen --value ssh.socket 2>/dev/null || true
  fi
  printf '%s\n' "$(ui_text '实际 TCP 监听：' 'Actual TCP listeners:')"
  if have ss; then ss -lntp 2>/dev/null | awk 'NR == 1 || /sshd|systemd.*fd=/' ; else printf '%s\n' 'ss unavailable / 未发现 ss'; fi
}

ui_ssh_port_menu() {
  local choice port confirm socket_active dropins dropin config_file
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
        if [ "${#port}" -gt 5 ] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
          printf '%s\n' "$(ui_text '端口号必须在 1-65535 之间。' 'Port must be between 1 and 65535.')"
          continue
        fi
        port=$((10#$port))
        if [ "$port" = 22 ]; then
          printf '%s\n' "$(ui_text '端口 22 已是当前默认端口，无需添加。' 'Port 22 is already the default port; no change needed.')"
          continue
        fi
        printf '%s\n' "$(ui_text '操作会先放行新端口，并保留 22 以便测试；不会自动关闭 22。' 'The new port will be allowed and 22 will be kept for testing; port 22 will not be closed automatically.')"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }

        socket_active=0
        systemctl is-active --quiet ssh.socket 2>/dev/null && socket_active=1
        if [ "$socket_active" -eq 1 ]; then
          dropins=$(systemctl show --property=DropInPaths --value ssh.socket 2>/dev/null || true)
          for dropin in $dropins; do
            if [ "${dropin##*/}" != 99-vps-guard.conf ]; then
              printf '%s\n' "$(ui_text '检测到自定义 ssh.socket drop-in；为避免覆盖现有设置，未修改。' 'A custom ssh.socket drop-in was found; no changes made to avoid overwriting it.')"
              continue 2
            fi
          done
          if [ -e /etc/systemd/system/ssh.socket.d/99-vps-guard.conf ] && ! grep -q '^# Managed by VPS Guard$' /etc/systemd/system/ssh.socket.d/99-vps-guard.conf; then
            printf '%s\n' "$(ui_text '管理器目标配置文件已存在且不是本工具创建；未覆盖。' 'The target drop-in exists and is not managed by VPS Guard; it was not overwritten.')"
            continue
          fi
        fi

        if have ufw && ufw status 2>/dev/null | grep -q 'Status: active'; then
          ufw allow "$port/tcp" || { printf '%s\n' "$(ui_text '放行新端口失败；未继续改 SSH。' 'Failed to allow the new port; SSH was not changed.')"; continue; }
        fi
        if [ "$socket_active" -eq 1 ]; then
          install -d -m 755 /etc/systemd/system/ssh.socket.d || continue
          cat > /etc/systemd/system/ssh.socket.d/99-vps-guard.conf <<EOF
# Managed by VPS Guard
[Socket]
ListenStream=
ListenStream=0.0.0.0:22
ListenStream=[::]:22
ListenStream=0.0.0.0:$port
ListenStream=[::]:$port
EOF
          if ! systemctl daemon-reload || ! systemctl restart ssh.socket; then
            printf '%s\n' "$(ui_text '重启 ssh.socket 失败；未自动回滚，请检查服务状态和配置。' 'Failed to restart ssh.socket; no automatic rollback was performed. Check service status and configuration.')"
            continue
          fi
        fi

        if [ -d /etc/ssh/sshd_config.d ]; then
          while IFS= read -r -d '' config_file; do
            sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' "$config_file" || break
          done < <(find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -print0)
        fi
        sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' /etc/ssh/sshd_config
        printf '\nPort %s\n' "$port" >> /etc/ssh/sshd_config
        if ! sshd -t 2>/dev/null; then
          printf '%s\n' "$(ui_text 'sshd 配置验证失败；未自动回滚，请立即检查配置。' 'sshd configuration validation failed; no automatic rollback was performed. Check the configuration immediately.')"
          continue
        fi
        if [ "$socket_active" -eq 0 ] && ! systemctl reload ssh 2>/dev/null && ! systemctl reload sshd 2>/dev/null; then
          printf '%s\n' "$(ui_text '重载 SSH 失败；未自动回滚，请检查服务状态。' 'Failed to reload SSH; no automatic rollback was performed. Check service status.')"
          continue
        fi
        if ss -lnt 2>/dev/null | grep -Eq "(^|[[:space:]:])${port}[[:space:]]"; then
          printf '%s\n' "$(ui_text '新端口正在监听。请另开终端测试登录；确认成功后再考虑移除 22。' 'The new port is listening. Test from another terminal; only consider removing 22 after login succeeds.')"
        else
          printf '%s\n' "$(ui_text '配置已写入，但未检测到新端口监听；请勿断开当前会话并检查 ssh.socket/SSH 状态。' 'Configuration was written, but the new listener was not detected. Keep this session open and inspect ssh.socket/SSH status.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

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
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
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
  if have systemctl && systemctl is-active --quiet ssh.socket 2>/dev/null; then
    printf '%s\n' "$(ui_text '检测到 ssh.socket 正在监听。请先使用本菜单的“SSH 端口与 socket 管理”设置端口，避免只修改 sshd_config 而实际监听不变。' 'ssh.socket is active. Use “SSH port and socket management” first; changing only sshd_config would not change the actual listener.')"
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

ui_docker_menu() {
  local choice containers selection container_id container_name action confirm
  local -a container_rows=()
  if ! have docker || ! docker info >/dev/null 2>&1; then
    printf '%s\n' "$(ui_text 'Docker 未安装，或守护进程不可用。' 'Docker is not installed or the daemon is unavailable.')"
    ui_pause
    return 1
  fi
  while true; do
    printf '\n%s\n' "$(ui_text '容器列表（包含端口映射）' 'Containers (including port mappings)')"
    docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
    printf '%s\n' \
      "1) $(ui_text '操作容器（启动/停止/重启）' 'Control a container (start/stop/restart)')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      0) return ;;
      1)
        containers=$(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}') || continue
        container_rows=()
        while IFS= read -r selection; do [ -n "$selection" ] && container_rows+=("$selection"); done <<< "$containers"
        if [ "${#container_rows[@]}" -eq 0 ]; then printf '%s\n' "$(ui_text '没有容器。' 'No containers found.')"; continue; fi
        for selection in "${!container_rows[@]}"; do printf '%2d) %s\n' "$((selection + 1))" "${container_rows[$selection]}"; done
        read -r -p "$(ui_text '选择容器编号（0 返回）：' 'Select container number (0 to return): ')" selection
        [ "$selection" = 0 ] && continue
        case "$selection" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
        if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#container_rows[@]}" ]; then printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue; fi
        IFS=$'\t' read -r container_id container_name _ <<< "${container_rows[$((selection - 1))]}"
        printf '%s\n' \
          "1) $(ui_text '启动' 'Start')" \
          "2) $(ui_text '停止' 'Stop')" \
          "3) $(ui_text '重启' 'Restart')" \
          "0) $(ui_text '返回' 'Back')"
        read -r -p '> ' action || return
        case "$action" in 1) action=start ;; 2) action=stop ;; 3) action=restart ;; 0) continue ;; *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
        printf '%s\n' "$(ui_text "将对容器 $container_name 执行 $action。" "About to $action container $container_name.")"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if docker "$action" "$container_id"; then printf '%s\n' "$(ui_text '容器操作完成。' 'Container action completed.')"; else printf '%s\n' "$(ui_text '容器操作失败。' 'Container action failed.')"; fi
        ui_pause
        ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

ui_scheduled_menu() {
  local choice crontab_text job confirm line_no total
  if ! have systemctl; then
    printf '%s\n' "$(ui_text 'systemd/systemctl 不可用。' 'systemd/systemctl is unavailable.')"
  else
    printf '\n%s\n' "$(ui_text 'systemd timers（只读）' 'systemd timers (read-only)')"
    systemctl list-timers --all --no-pager 2>/dev/null || true
  fi
  while true; do
    printf '\n%s\n' "$(ui_text 'root 用户的 Cron 定时任务' 'Root user Cron jobs')"
    if have crontab; then
      crontab_text=$(crontab -l 2>/dev/null || true)
      if [ -n "$crontab_text" ]; then printf '%s\n' "$crontab_text" | nl -ba; else printf '%s\n' "$(ui_text '当前没有 root crontab。' 'No root crontab is configured.')"; fi
    else
      printf '%s\n' "$(ui_text 'crontab 命令不可用。' 'crontab command is unavailable.')"
    fi
    printf '%s\n' \
      "1) $(ui_text '新增 Cron 任务' 'Add a Cron job')" \
      "2) $(ui_text '删除 Cron 任务' 'Delete a Cron job')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        if ! root_required || ! have crontab; then continue; fi
        read -r -p "$(ui_text '输入完整 Cron 行（5 个时间字段 + 命令）：' 'Enter a full Cron line (5 schedule fields + command): ')" job
        if ! printf '%s\n' "$job" | awk 'NF >= 6 {ok=1} END {exit !ok}'; then printf '%s\n' "$(ui_text '格式看起来不完整，必须含 5 个时间字段和命令。' 'The line looks incomplete; it must contain 5 schedule fields and a command.')"; continue; fi
        printf '%s\n' "$(ui_text '即将添加：' 'About to add:')" "$job"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if [ -n "$crontab_text" ]; then
          if printf '%s\n%s\n' "$crontab_text" "$job" | crontab -; then printf '%s\n' "$(ui_text 'Cron 任务已添加。' 'Cron job added.')"; else printf '%s\n' "$(ui_text '添加失败。' 'Add failed.')"; fi
        elif printf '%s\n' "$job" | crontab -; then
          printf '%s\n' "$(ui_text 'Cron 任务已添加。' 'Cron job added.')"
        else
          printf '%s\n' "$(ui_text '添加失败。' 'Add failed.')"
        fi
        ;;
      2)
        if ! root_required || ! have crontab || [ -z "$crontab_text" ]; then continue; fi
        read -r -p "$(ui_text '输入要删除的行号（0 返回）：' 'Line number to delete (0 to return): ')" line_no
        [ "$line_no" = 0 ] && continue
        case "$line_no" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '行号无效。' 'Invalid line number.')"; continue ;; esac
        total=$(printf '%s\n' "$crontab_text" | awk 'END {print NR}')
        if [ "$line_no" -lt 1 ] || [ "$line_no" -gt "$total" ]; then printf '%s\n' "$(ui_text '行号超出范围。' 'Line number is out of range.')"; continue; fi
        printf '%s\n' "$(ui_text '将删除此任务行：' 'The following Cron line will be deleted:')"
        printf '%s\n' "$crontab_text" | sed -n "${line_no}p"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        if printf '%s\n' "$crontab_text" | awk -v n="$line_no" 'NR != n' | crontab -; then printf '%s\n' "$(ui_text 'Cron 行已删除。' 'Cron line deleted.')"; else printf '%s\n' "$(ui_text '删除失败。' 'Delete failed.')"; fi
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
    ui_pause
  done
}

ui_cleanup_menu() {
  local choice confirm size
  while true; do
    printf '\n%s\n' "$(ui_text '安全清理（先预览，不自动删除）' 'Safe cleanup (preview before deletion)')"
    printf '%s\n' \
      "1) $(ui_text '清理 APT 缓存' 'Clean APT cache')" \
      "2) $(ui_text '清理已轮转的 systemd 日志' 'Vacuum rotated systemd journals')" \
      "3) $(ui_text '删除已停止的 Docker 容器' 'Remove stopped Docker containers')" \
      "4) $(ui_text '删除悬空 Docker 镜像' 'Remove dangling Docker images')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    [ "$choice" = 0 ] && return
    case "$choice" in
      1)
        if ! have apt-get; then printf '%s\n' 'apt-get unavailable / apt-get 不可用'; continue; fi
        size=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
        printf '%s\n' "$(ui_text "将清理 APT 缓存，当前约 $size。" "APT cache to clean, currently about $size.")"
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        apt-get clean
        ;;
      2)
        if ! have journalctl; then printf '%s\n' 'journalctl unavailable / journalctl 不可用'; continue; fi
        journalctl --disk-usage 2>/dev/null || true
        read -r -p "$(ui_text '输入保留大小（如 200M）：' 'Maximum size to keep (for example 200M): ')" size
        if ! [[ "$size" =~ ^[0-9]+[KkMmGgTt]?$ ]]; then printf '%s\n' "$(ui_text '大小格式无效。' 'Invalid size format.')"; continue; fi
        read -r -p "$(ui_text '输入 APPLY 确认：' 'Type APPLY to confirm: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        journalctl --vacuum-size="$size"
        ;;
      3)
        if ! have docker || ! docker info >/dev/null 2>&1; then printf '%s\n' "$(ui_text 'Docker 不可用。' 'Docker is unavailable.')"; continue; fi
        printf '%s\n' "$(ui_text '以下已停止容器将被删除（容器可写层数据也会丢失）：' 'These stopped containers will be removed (writable-layer data will be lost):')"
        docker ps -a --filter status=exited --filter status=created --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
        read -r -p "$(ui_text '输入 APPLY 删除列出的容器：' 'Type APPLY to remove the listed containers: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        docker container prune --force
        ;;
      4)
        if ! have docker || ! docker info >/dev/null 2>&1; then printf '%s\n' "$(ui_text 'Docker 不可用。' 'Docker is unavailable.')"; continue; fi
        printf '%s\n' "$(ui_text '以下悬空镜像将被删除：' 'These dangling images will be removed:')"
        docker image ls --filter dangling=true
        read -r -p "$(ui_text '输入 APPLY 删除悬空镜像：' 'Type APPLY to remove dangling images: ')" confirm
        [ "$confirm" = APPLY ] || { say cancel; continue; }
        docker image prune --force
        ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
    esac
    ui_pause
  done
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

ui_export_status() {
  printf '\n===== VPS Guard configuration status / 配置状态 =====\n'
  audit_ssh
  audit_network
  if have fail2ban-client; then fail2ban-client status 2>/dev/null || true; fi
  if have docker && docker info >/dev/null 2>&1; then docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null || true; fi
  printf '%s\n' "$(ui_text '状态已输出到终端；没有创建报告文件。' 'Status was printed to the terminal; no report file was created.')"
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
  printf '\n%s\n' "$(ui_text '输入 APPLY 执行 apt-get update 和 apt-get upgrade。系统不会自动重启。输入 0 返回。' 'Type APPLY to run apt-get update and apt-get upgrade. The system will not reboot automatically. Type 0 to return.')"
  local answer
  read -r -p '> ' answer || return
  case "$answer" in
    APPLY)
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
