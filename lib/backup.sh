#!/usr/bin/env bash
set -u

backup_begin() {
  ensure_state || return 1
  BACKUP_ID=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_DIR="$STATE_DIR/$BACKUP_ID"
  install -d -m 700 "$BACKUP_DIR"
  printf '%s\n' "$BACKUP_DIR" > "$STATE_DIR/latest"
}

backup_file() {
  local source=$1 name
  [ -e "$source" ] || return 0
  name=$(printf '%s' "$source" | sed 's#^/##; s#/#__#g')
  cp -a "$source" "$BACKUP_DIR/$name" || return 1
  printf '%s\n' "$source" >> "$BACKUP_DIR/files"
}

rollback_latest() {
  local dir source name
  dir=$(cat "$STATE_DIR/latest" 2>/dev/null) || return 1
  [ -d "$dir" ] || return 1
  [ -f "$dir/files" ] || return 1
  while IFS= read -r source; do
    name=$(printf '%s' "$source" | sed 's#^/##; s#/#__#g')
    [ -e "$dir/$name" ] || continue
    cp -a "$dir/$name" "$source" || return 1
  done < "$dir/files"
}
