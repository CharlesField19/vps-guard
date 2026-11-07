#!/usr/bin/env bash

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
    printf '%s\n' "$(ui_text 'Cron 任务由系统按设定时间自动执行。新增前核对时间表达式和命令；这里仅管理 root 用户 crontab，不改其他用户任务。' 'Cron jobs run commands automatically on a schedule. Check the schedule and command carefully; this menu manages only root crontab, not other users.')"
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
        read -r -p "$(ui_text '确认添加？输入 y/n：' 'Confirm add? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
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
        printf '%s\n' "$(ui_text '删除的是 root crontab 中对应的单行任务；输入 0 返回。取消确认不会更改 crontab。' 'This deletes one selected line from root crontab; enter 0 to return. Cancelling leaves crontab unchanged.')"
        read -r -p "$(ui_text '输入要删除的行号（0 返回）：' 'Line number to delete (0 to return): ')" line_no
        [ "$line_no" = 0 ] && continue
        case "$line_no" in ''|*[!0-9]*) printf '%s\n' "$(ui_text '行号无效。' 'Invalid line number.')"; continue ;; esac
        total=$(printf '%s\n' "$crontab_text" | awk 'END {print NR}')
        if [ "$line_no" -lt 1 ] || [ "$line_no" -gt "$total" ]; then printf '%s\n' "$(ui_text '行号超出范围。' 'Line number is out of range.')"; continue; fi
        printf '%s\n' "$(ui_text '将删除此任务行：' 'The following Cron line will be deleted:')"
        printf '%s\n' "$crontab_text" | sed -n "${line_no}p"
        read -r -p "$(ui_text '确认删除？输入 y/n：' 'Confirm deletion? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if printf '%s\n' "$crontab_text" | awk -v n="$line_no" 'NR != n' | crontab -; then printf '%s\n' "$(ui_text 'Cron 行已删除。' 'Cron line deleted.')"; else printf '%s\n' "$(ui_text '删除失败。' 'Delete failed.')"; fi
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
    ui_pause
  done
}
