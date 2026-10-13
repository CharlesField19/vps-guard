#!/usr/bin/env bash
audit_network() {
  heading firewall
  if have ufw; then
    ufw status verbose 2>/dev/null || true
  else
    notice 'UFW not installed / 未安装 UFW'
  fi
  if have firewall-cmd; then
    echo 'Firewalld / Firewalld 状态:'
    firewall-cmd --state 2>/dev/null || true
    firewall-cmd --list-all 2>/dev/null || true
  fi
  if have nft; then
    echo 'nftables ruleset summary / nftables 规则摘要:'
    nft list tables 2>/dev/null || true
  fi
  echo 'Listening ports / 监听端口:'
  if have ss; then ss -tulpen 2>/dev/null || true; else notice 'ss command unavailable / 缺少 ss 命令'; fi
}
