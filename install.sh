#!/usr/bin/env bash

install_dir_blocked() {
  case "$1" in
    /|/opt|/etc|/usr|/usr/bin|/usr/sbin|/usr/local|/usr/local/bin|/usr/local/sbin|/var|/var/lib|/var/log|/var/cache|/var/run|/var/tmp|/home|/root|/bin|/sbin|/lib|/lib32|/lib64|/libx32|/boot|/tmp|/proc|/sys|/dev|/run|/srv)
      return 0
      ;;
    /etc/*|/usr/bin/*|/usr/sbin/*|/usr/local/bin/*|/usr/local/sbin/*|/bin/*|/sbin/*|/lib/*|/lib32/*|/lib64/*|/libx32/*|/boot/*|/dev/*|/proc/*|/sys/*|/run/*|/tmp/*|/var/tmp/*|/var/log/*|/var/cache/*|/var/run/*)
      return 0
      ;;
  esac
  return 1
}

install_dir_safe() {
  local dir=$1 resolved
  case "$dir" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$dir" in
    *..*) return 1 ;;
  esac
  dir=${dir%/}
  [ -n "$dir" ] || return 1
  install_dir_blocked "$dir" && return 1
  case "$dir" in
    /*/*) ;;
    *) return 1 ;;
  esac
  if [ -L "$dir" ]; then
    return 1
  fi
  if [ -e "$dir" ] && [ ! -d "$dir" ]; then
    return 1
  fi
  if [ -e "$dir" ]; then
    resolved=$(readlink -f -- "$dir") || return 1
    install_dir_blocked "$resolved" && return 1
  fi
  return 0
}

if [ "${VPS_GUARD_SOURCE_ONLY:-}" = 1 ]; then
  return 0 2>/dev/null || exit 0
fi

set -e

REPO="${VPS_GUARD_REPO:-CharlesField19/vps-guard}"
REF="${VPS_GUARD_REF:-main}"
INSTALL_DIR="${VPS_GUARD_DIR:-/opt/vps-guard}"

[ "$(id -u)" -eq 0 ] || { echo 'Please run as root / 请使用 root 运行'; exit 1; }
install_dir_safe "$INSTALL_DIR" || { echo "Refusing unsafe install path: $INSTALL_DIR / 拒绝不安全的安装路径: $INSTALL_DIR"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo 'curl is required / 需要 curl'; exit 1; }
command -v tar >/dev/null 2>&1 || { echo 'tar is required / 需要 tar'; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/vps-guard.tar.gz"
url="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"

echo "Downloading $REPO ($REF) / 正在下载项目..."
curl -fL --retry 2 --connect-timeout 10 --max-time 120 "$url" -o "$archive"
if [ -n "${VPS_GUARD_SHA256:-}" ]; then
  command -v sha256sum >/dev/null 2>&1 || { echo 'sha256sum is required for VPS_GUARD_SHA256 / 校验需要 sha256sum'; exit 1; }
  printf '%s  %s\n' "$VPS_GUARD_SHA256" "$archive" | sha256sum -c - || { echo 'Checksum verification failed / 校验失败'; exit 1; }
fi
mkdir -p "$tmp/source"
tar -xzf "$archive" -C "$tmp/source"
entries=$(find "$tmp/source" -mindepth 1 -maxdepth 1 | wc -l)
[ "$entries" -eq 1 ] || { echo 'Invalid project archive: expected one top-level entry / 项目压缩包无效：顶层条目不唯一'; exit 1; }
source_dir=$(find "$tmp/source" -mindepth 1 -maxdepth 1 -type d -print -quit)
[ -n "$source_dir" ] || { echo 'Invalid project archive / 项目压缩包无效'; exit 1; }

if [ -e "$INSTALL_DIR" ]; then
  echo "Upgrading existing installation / 正在覆盖升级现有安装"
  backup_root=${VPS_GUARD_BACKUP_DIR:-/var/backups/vps-guard}
  backup_dir=$backup_root/$(date -u +%Y%m%dT%H%M%SZ)
  if ! mkdir -p "$backup_dir" || ! cp -a "$INSTALL_DIR/." "$backup_dir/"; then
    echo "Unable to back up $INSTALL_DIR; installation aborted / 无法备份现有安装，已中止"
    exit 1
  fi
  echo "Backed up to $backup_dir / 已备份到 $backup_dir"
  rm -rf -- "$INSTALL_DIR"
fi
mkdir -p "$(dirname "$INSTALL_DIR")"
cp -a "$source_dir" "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR/vps-guard.sh"
chmod 755 "$INSTALL_DIR/install.sh" 2>/dev/null || true
echo "Installed at $INSTALL_DIR / 已安装到 $INSTALL_DIR"
if [ "${VPS_GUARD_NO_UI:-0}" = 1 ]; then
  echo "Installed without opening the menu / 已安装，未打开菜单"
  exit 0
fi
cd "$INSTALL_DIR"
# When install.sh is piped from curl, stdin belongs to the pipe.
# Read the interactive menu from the terminal instead.
if [ -r /dev/tty ]; then
  bash ./vps-guard.sh ui </dev/tty
else
  bash ./vps-guard.sh ui
fi
