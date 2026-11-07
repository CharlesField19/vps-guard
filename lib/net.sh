#!/usr/bin/env bash

ipv6_available() {
  [ -d /proc/sys/net/ipv6 ] || return 1
  [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 1)" = 0 ]
}

tcp_port_in_ss_lines() {
  local port=$1
  case "$port" in ''|*[!0-9]*) return 1 ;; esac
  awk -v port="$port" '
    {
      n = split($4, parts, ":")
      if (n < 2) next
      p = parts[n]
      gsub(/[][]/, "", p)
      if (p == port) found = 1
    }
    END { exit found ? 0 : 1 }
  '
}

tcp_port_listening() {
  local port=$1
  have ss || return 1
  ss -H -lnt 2>/dev/null | tcp_port_in_ss_lines "$port"
}
