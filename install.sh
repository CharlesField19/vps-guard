#!/usr/bin/env bash
set -e

REPO="${VPS_GUARD_REPO:-CharlesField19/vps-guard}"
REF="${VPS_GUARD_REF:-main}"
INSTALL_DIR="${VPS_GUARD_DIR:-/opt/vps-guard}"

[ "$(id -u)" -eq 0 ] || { echo 'Please run as root / 请使用 root 运行'; exit 1; }
command -v curl >/dev/null 2>&1 || { echo 'curl is required / 需要 curl'; exit 1; }
command -v tar >/dev/null 2>&1 || { echo 'tar is required / 需要 tar'; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/vps-guard.tar.gz"
url="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"

echo "Downloading $REPO ($REF) / 正在下载项目..."
curl -fL --retry 2 --connect-timeout 10 --max-time 120 "$url" -o "$archive"
mkdir -p "$tmp/source"
tar -xzf "$archive" -C "$tmp/source"
source_dir=$(find "$tmp/source" -mindepth 1 -maxdepth 1 -type d -print -quit)
[ -n "$source_dir" ] || { echo 'Invalid project archive / 项目压缩包无效'; exit 1; }

if [ -e "$INSTALL_DIR" ]; then
  backup="$INSTALL_DIR.backup.$(date +%Y%m%d%H%M%S)"
  mv "$INSTALL_DIR" "$backup"
  echo "Previous installation moved to $backup / 旧版本已备份"
fi
mkdir -p "$(dirname "$INSTALL_DIR")"
cp -a "$source_dir" "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR/vps-guard.sh"
chmod 755 "$INSTALL_DIR/install.sh" 2>/dev/null || true
echo "Installed at $INSTALL_DIR / 已安装到 $INSTALL_DIR"
cd "$INSTALL_DIR"
exec bash ./vps-guard.sh ui
