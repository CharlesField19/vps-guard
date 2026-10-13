#!/usr/bin/env bash
audit_system() {
  heading system
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || true
  printf 'OS / 系统: %s\n' "${PRETTY_NAME:-unknown}"
  printf 'Kernel / 内核: %s\n' "$(uname -r)"
  printf 'Uptime / 运行时间: %s\n' "$(uptime -p 2>/dev/null || uptime)"
  printf 'Identity / 身份: %s\n' "$(id -un)"
  printf 'Time / 时间: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}

audit_resources() {
  heading resources
  df -hT / 2>/dev/null || true
  free -h 2>/dev/null || true
  swapon --show 2>/dev/null || true
  sysctl net.ipv4.ip_forward net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects net.ipv4.conf.all.rp_filter kernel.randomize_va_space 2>/dev/null || true
}
