#!/usr/bin/env bash

ui_resources_status() {
  printf '\n%s\n' "$(ui_text '资源监控（只读）' 'Resource monitoring (read-only)')"
  printf '%s\n' '--- load / 负载 ---'; uptime 2>/dev/null || true
  printf '%s\n' '--- memory / 内存 ---'; free -h 2>/dev/null || true
  printf '%s\n' '--- disks / 磁盘 ---'; df -hT 2>/dev/null || true
  printf '%s\n' '--- inode ---'; df -ih 2>/dev/null || true
  printf '%s\n' '--- top CPU processes / CPU 占用进程 ---'; ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 11 || true
  printf '%s\n' '--- top memory processes / 内存占用进程 ---'; ps -eo pid,user,%cpu,%mem,comm --sort=-%mem 2>/dev/null | head -n 11 || true
}
