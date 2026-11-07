#!/usr/bin/env bash
# Compatibility loader: menu functions live in modules/ui/*.sh.
UI_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ui
for file in "$UI_DIR"/*.sh; do
  [ -f "$file" ] && . "$file"
done
