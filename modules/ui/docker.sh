#!/usr/bin/env bash

ui_docker_menu() {
  local choice containers selection container_id container_name action confirm package_action lines
  local -a packages=()
  local -a container_rows=()
  while true; do
    if have docker && docker info >/dev/null 2>&1; then
      printf '\n%s\n' "$(ui_text '容器列表（包含端口映射）' 'Containers (including port mappings)')"
      docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
    else
      printf '%s\n' "$(ui_text 'Docker 未安装，或守护进程不可用。可用选项 2 安装/更新。' 'Docker is not installed or the daemon is unavailable. Use option 2 to install/update it.')"
    fi
    printf '%s\n' \
      "1) $(ui_text '操作容器（启动/停止/重启）' 'Control a container (start/stop/restart)')" \
      "2) $(ui_text '安装/更新 Docker' 'Install/update Docker')" \
      "3) $(ui_text '查看容器日志（只读）' 'View container logs (read-only)')" \
      "4) $(ui_text 'Nginx 配置测试/安全重载' 'Nginx config test/safe reload')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      0) return ;;
      3)
        if ! have docker || ! docker info >/dev/null 2>&1; then
          printf '%s\n' "$(ui_text 'Docker 当前不可用。' 'Docker is unavailable.')"
          continue
        fi
        containers=$(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}') || continue
        container_rows=()
        while IFS= read -r selection; do [ -n "$selection" ] && container_rows+=("$selection"); done <<< "$containers"
        if [ "${#container_rows[@]}" -eq 0 ]; then printf '%s\n' "$(ui_text '没有容器。' 'No containers found.')"; continue; fi
        for selection in "${!container_rows[@]}"; do printf '%2d) %s\n' "$((selection + 1))" "${container_rows[$selection]}"; done
        read -r -p "$(ui_text '选择要查看日志的容器编号（0 返回）：' 'Select container for logs (0 to return): ')" selection
        [ "$selection" = 0 ] && continue
        case "$selection" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
        if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#container_rows[@]}" ]; then printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue; fi
        IFS=$'\t' read -r container_id container_name _ <<< "${container_rows[$((selection - 1))]}"
        read -r -p "$(ui_text '显示最近多少行（默认 100，最多 1000）：' 'Recent lines (default 100, maximum 1000): ')" lines
        [ -n "$lines" ] || lines=100
        case "$lines" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '行数无效。' 'Invalid line count.')"; continue ;; esac
        if [ "${#lines}" -gt 4 ]; then lines=1000; fi
        [ "$lines" -ge 1 ] || { printf '%s\n' "$(ui_text '行数必须大于 0。' 'Line count must be greater than zero.')"; continue; }
        [ "$lines" -gt 1000 ] && lines=1000
        printf '%s\n' "$(ui_text '日志可能包含 IP、用户名或令牌；分享前请脱敏。' 'Logs may contain IPs, usernames or tokens; redact before sharing.')"
        docker logs --tail "$lines" --timestamps "$container_id" 2>&1 || true
        ui_pause
        ;;
      4)
        if ! have docker || ! docker info >/dev/null 2>&1; then
          printf '%s\n' "$(ui_text 'Docker 当前不可用。' 'Docker is unavailable.')"
          continue
        fi
        containers=$(docker ps --filter status=running --format '{{.ID}}\t{{.Names}}') || continue
        container_rows=()
        while IFS= read -r selection; do [ -n "$selection" ] && container_rows+=("$selection"); done <<< "$containers"
        if [ "${#container_rows[@]}" -eq 0 ]; then printf '%s\n' "$(ui_text '没有运行中的容器。' 'No running containers found.')"; continue; fi
        printf '%s\n' "$(ui_text '只会测试所选容器内的 Nginx；测试通过后才提供 reload。' 'Tests Nginx inside the selected container; reload is offered only after a successful test.')"
        for selection in "${!container_rows[@]}"; do printf '%2d) %s\n' "$((selection + 1))" "${container_rows[$selection]}"; done
        read -r -p "$(ui_text '选择 Nginx 容器编号（0 返回）：' 'Select Nginx container (0 to return): ')" selection
        [ "$selection" = 0 ] && continue
        case "$selection" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;; esac
        if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#container_rows[@]}" ]; then printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue; fi
        IFS=$'\t' read -r container_id container_name <<< "${container_rows[$((selection - 1))]}"
        if ! docker exec "$container_id" nginx -t; then
          printf '%s\n' "$(ui_text '配置测试失败；未执行 reload。请先修复配置。' 'Config test failed; reload was not run. Fix the config first.')"
          ui_pause
          continue
        fi
        read -r -p "$(ui_text "容器 $container_name 测试通过。确认 reload？输入 y/n：" "Container $container_name passed. Confirm reload? y/n: ")" confirm
        if is_yes "$confirm"; then
          docker exec "$container_id" nginx -s reload || printf '%s\n' "$(ui_text 'reload 失败；检查容器日志和 Nginx 状态。' 'Reload failed; check container logs and Nginx status.')"
        else
          say cancel
        fi
        ui_pause
        ;;
      1)
        if ! have docker || ! docker info >/dev/null 2>&1; then
          printf '%s\n' "$(ui_text 'Docker 当前不可用，请先执行选项 2。' 'Docker is unavailable; run option 2 first.')"
          continue
        fi
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
        read -r -p "$(ui_text '确认容器操作？输入 y/n：' 'Confirm container action? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if docker "$action" "$container_id"; then printf '%s\n' "$(ui_text '容器操作完成。' 'Container action completed.')"; else printf '%s\n' "$(ui_text '容器操作失败。' 'Container action failed.')"; fi
        ui_pause
        ;;
      2)
        if ! root_required || ! have apt-get || ! have apt-cache; then continue; fi
        printf '%s\n' \
          "1) $(ui_text '安装/确保已安装' 'Install/ensure installed')" \
          "2) $(ui_text '仅更新已安装版本' 'Upgrade installed packages only')" \
          "0) $(ui_text '返回' 'Back')"
        read -r -p '> ' package_action || return
        case "$package_action" in
          1) package_action=install ;;
          2) package_action=upgrade ;;
          0) continue ;;
          *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
        esac
        packages=(docker.io)
        apt-cache show docker-compose-plugin >/dev/null 2>&1 && packages+=(docker-compose-plugin)
        if [ "$package_action" = install ]; then
          printf '%s\n' "$(ui_text '将安装 Docker：' 'Docker packages to install:') ${packages[*]}"
        else
          printf '%s\n' "$(ui_text '将仅更新已安装的 Docker 软件包：' 'Docker packages to upgrade if installed:') ${packages[*]}"
        fi
        read -r -p "$(ui_text '确认安装/更新？输入 y/n：' 'Confirm install/update? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if apt-get update; then
          if [ "$package_action" = install ]; then
            apt-get install -y "${packages[@]}"
          else
            apt-get install --only-upgrade -y "${packages[@]}"
          fi
          if [ "$?" -eq 0 ]; then
            systemctl enable --now docker 2>/dev/null || true
            printf '%s\n' "$(ui_text 'Docker 安装/更新完成；已尝试启用并启动 Docker 服务。' 'Docker install/update completed; the Docker service was enabled and started when possible.')"
          else
            printf '%s\n' "$(ui_text 'Docker 安装/更新失败，请检查上方 APT 输出。' 'Docker install/update failed; review the APT output above.')"
          fi
        fi
        ui_pause
        ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}
