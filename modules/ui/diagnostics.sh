#!/usr/bin/env bash

ui_extended_diagnostics() {
  local choice target scheme host port output
  while true; do
    printf '\n%s\n' "$(ui_text '扩展诊断（只读；不安装软件、不修改配置）' 'Extended diagnostics (read-only; no installs or config changes)')"
    printf '%s\n' \
      "1) $(ui_text '磁盘占用较大目录' 'Largest disk usage')" \
      "2) $(ui_text '失败服务与重启提示' 'Failed services and reboot status')" \
      "3) $(ui_text 'HTTP/TLS 检查' 'HTTP/TLS check')" \
      "4) $(ui_text '路由追踪（可选工具）' 'Route trace (optional tool)')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        printf '%s\n' "$(ui_text '扫描 /var、/opt、/home 的一层目录用量；只显示结果，不删除文件。' 'Shows one-level usage under /var, /opt and /home; does not delete anything.')"
        if have du; then
          if ! have timeout; then
            printf '%s\n' "$(ui_text '缺少 timeout 命令；为避免无界扫描，已跳过目录遍历。' 'timeout is unavailable; skipped directory scan to avoid an unbounded walk.')"
          else
          for target in /var /opt /home; do
            [ -d "$target" ] || continue
            printf '\n--- %s ---\n' "$target"
            timeout 45 du -x -h --max-depth=1 "$target" 2>/dev/null | sort -h | tail -n 12 || printf '%s\n' "$(ui_text '扫描超时或部分目录不可读。' 'Scan timed out or some directories were unreadable.')"
          done
          fi
          if have docker && docker info >/dev/null 2>&1; then docker system df; fi
        else
          printf '%s\n' "$(ui_text 'du 命令不可用。' 'du is unavailable.')"
        fi
        ui_pause
        ;;
      2)
        if have systemctl; then
          printf '%s\n' '--- failed units ---'
          systemctl --failed --no-pager 2>&1 || true
        else
          printf '%s\n' "$(ui_text 'systemctl 不可用。' 'systemctl is unavailable.')"
        fi
        if [ -e /var/run/reboot-required ]; then
          printf '%s\n' "$(ui_text '系统标记需要重启；本工具不会自动重启。' 'System indicates a reboot is required; this tool will not reboot automatically.')"
        else
          printf '%s\n' "$(ui_text '未发现 Debian/Ubuntu 的 reboot-required 标记；这不保证所有服务无需重启。' 'No Debian/Ubuntu reboot-required marker found; this does not guarantee no service restart is needed.')"
        fi
        if have journalctl; then journalctl -p err..alert --since '24 hours ago' --no-pager -n 80 2>&1 || true; fi
        ui_pause
        ;;
      3)
        if ! have curl; then printf '%s\n' "$(ui_text 'curl 不可用；未安装任何软件。' 'curl is unavailable; no software was installed.')"; continue; fi
        read -r -p "$(ui_text '输入域名或 URL（例如 https://example.com）：' 'Enter domain or URL (for example https://example.com): ')" target
        case "$target" in
          https://*) scheme=https; host=${target#https://} ;;
          http://*) scheme=http; host=${target#http://} ;;
          *[!A-Za-z0-9.-]*| '') printf '%s\n' "$(ui_text '目标格式无效；仅接受域名或 http(s) URL，不接受路径/参数。' 'Invalid target; enter a hostname or http(s) URL without path/query.')"; continue ;;
          *) scheme=https; host=$target ;;
        esac
        host=${host%%/*}
        case "$host" in ''|.*|*..*|*:*|*[^A-Za-z0-9.-]*) printf '%s\n' "$(ui_text '主机名格式无效；暂不支持 URL 显式指定端口。' 'Invalid hostname; explicit URL ports are not supported.')"; continue ;; esac
        printf '%s\n' "$(ui_text '检查限制为 10 秒；不会修改 DNS、证书或 Web 配置。' 'Request timeout is 10 seconds; DNS, certificates and web config are not modified.')"
        curl -sSIL --max-time 10 --connect-timeout 5 -o /dev/null -w 'HTTP status: %{http_code}\nRemote IP: %{remote_ip}\nTLS verify: %{ssl_verify_result}\n' "$scheme://$host/" 2>&1 || true
        if [ "$scheme" = https ] && have timeout && have openssl; then
          timeout 12 openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>&1 || true
        fi
        ui_pause
        ;;
      4)
        if have mtr && have timeout; then
          read -r -p "$(ui_text '输入目标域名/IP：' 'Enter destination hostname/IP: ')" target
          case "$target" in ''|*[!A-Za-z0-9.:-]*) printf '%s\n' "$(ui_text '目标格式无效。' 'Invalid target.')"; continue ;; esac
          printf '%s\n' "$(ui_text '最多 10 个探测周期；中间节点丢包可能是 ICMP 限速，不能单独判故障。' 'Limited to 10 probes; intermediate loss may be ICMP rate limiting and is not by itself proof of a fault.')"
          timeout 30 mtr -r -w -c 10 "$target" 2>&1 || true
        elif have traceroute && have timeout; then
          read -r -p "$(ui_text '输入目标域名/IP：' 'Enter destination hostname/IP: ')" target
          case "$target" in ''|*[!A-Za-z0-9.:-]*) printf '%s\n' "$(ui_text '目标格式无效。' 'Invalid target.')"; continue ;; esac
          printf '%s\n' "$(ui_text '最多 12 跳；中间节点不响应不等于目标不可达。' 'Limited to 12 hops; an intermediate non-response does not prove the destination is unreachable.')"
          timeout 30 traceroute -m 12 -w 2 "$target" 2>&1 || true
        else
          printf '%s\n' "$(ui_text '未安装 mtr/traceroute/timeout 中的必要工具；为保持安全，本工具不会自动安装。' 'A required mtr/traceroute/timeout tool is unavailable; this tool will not install packages automatically.')"
        fi
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
ui_export_status() {
  printf '\n===== VPS Guard configuration status / 配置状态 =====\n'
  audit_ssh
  audit_network
  if have fail2ban-client; then fail2ban-client status 2>/dev/null || true; fi
  if have docker && docker info >/dev/null 2>&1; then docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null || true; fi
  printf '%s\n' "$(ui_text '状态已输出到终端；没有创建报告文件。' 'Status was printed to the terminal; no report file was created.')"
}
