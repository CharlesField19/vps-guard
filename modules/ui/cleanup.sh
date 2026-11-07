#!/usr/bin/env bash

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
        printf '%s\n' "$(ui_text 'APT 缓存是 apt 下载的软件包安装文件，清理它可释放磁盘空间；不会卸载已安装软件，但之后重新安装/升级时可能需要重新下载。' 'The APT cache stores downloaded package files. Cleaning it frees disk space; it does not uninstall installed software, but later installs/upgrades may need to download packages again.')"
        if ! have apt-get; then printf '%s\n' 'apt-get unavailable / apt-get 不可用'; continue; fi
        size=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
        printf '%s\n' "$(ui_text "将清理 APT 缓存，当前约 $size。" "APT cache to clean, currently about $size.")"
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        apt-get clean
        ;;
      2)
        printf '%s\n' "$(ui_text 'systemd 日志真空清理会按指定上限删除较旧日志；可能失去排查历史问题所需的记录。' 'Vacuuming systemd journals removes older logs to meet the selected size limit; historical troubleshooting records may be lost.')"
        if ! have journalctl; then printf '%s\n' 'journalctl unavailable / journalctl 不可用'; continue; fi
        journalctl --disk-usage 2>/dev/null || true
        read -r -p "$(ui_text '输入保留大小（如 200M）：' 'Maximum size to keep (for example 200M): ')" size
        if ! [[ "$size" =~ ^[0-9]+[KkMmGgTt]?$ ]]; then printf '%s\n' "$(ui_text '大小格式无效。' 'Invalid size format.')"; continue; fi
        if [[ "$size" =~ ^0+[KkMmGgTt]?$ ]]; then printf '%s\n' "$(ui_text '保留大小必须大于 0。' 'The retained size must be greater than zero.')"; continue; fi
        read -r -p "$(ui_text '确认执行？输入 y/n：' 'Confirm? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        journalctl --vacuum-size="$size"
        ;;
      3)
        printf '%s\n' "$(ui_text '已停止容器可能含有未写入卷的容器内数据；删除后通常无法恢复。卷和运行中容器不会由此操作删除。' 'Stopped containers may contain data outside volumes; deleting them is usually irreversible. Volumes and running containers are not targeted.')"
        if ! have docker || ! docker info >/dev/null 2>&1; then printf '%s\n' "$(ui_text 'Docker 不可用。' 'Docker is unavailable.')"; continue; fi
        printf '%s\n' "$(ui_text '以下已停止容器将被删除（容器可写层数据也会丢失）：' 'These stopped containers will be removed (writable-layer data will be lost):')"
        docker ps -a --filter status=exited --filter status=created --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
        read -r -p "$(ui_text '确认删除列出的容器？输入 y/n：' 'Confirm removing the listed containers? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        docker container prune --force
        ;;
      4)
        printf '%s\n' "$(ui_text '悬空镜像是没有标签且没有容器引用的镜像层；删除后需要时可重新拉取或构建。' 'Dangling images are untagged image layers not referenced by containers; they can be pulled or built again if needed.')"
        if ! have docker || ! docker info >/dev/null 2>&1; then printf '%s\n' "$(ui_text 'Docker 不可用。' 'Docker is unavailable.')"; continue; fi
        printf '%s\n' "$(ui_text '以下悬空镜像将被删除：' 'These dangling images will be removed:')"
        docker image ls --filter dangling=true
        read -r -p "$(ui_text '确认删除悬空镜像？输入 y/n：' 'Confirm removing dangling images? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        docker image prune --force
        ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')"; continue ;;
    esac
    ui_pause
  done
}
