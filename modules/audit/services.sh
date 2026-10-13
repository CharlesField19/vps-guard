#!/usr/bin/env bash
audit_services() {
  heading services
  for service in fail2ban auditd apparmor ufw docker; do
    printf '%-12s ' "$service"
    if have systemctl; then
      systemctl is-active "$service" 2>/dev/null || echo 'not-active / 未运行'
    else
      echo 'systemd unavailable / systemd 不可用'
      break
    fi
  done
  if have fail2ban-client; then
    if fail2ban-client status sshd 2>/dev/null; then :; else notice 'Fail2Ban sshd jail unavailable / SSH jail 不可用'; fi
  else
    echo 'Fail2Ban client not installed / 未安装 Fail2Ban 客户端'
  fi
}

audit_docker() {
  heading docker
  if ! have docker; then echo 'Docker not installed / 未安装 Docker'; return; fi
  if ! docker info >/dev/null 2>&1; then notice 'Docker CLI exists but daemon is unavailable or access is denied / Docker 客户端存在，但守护进程不可用或权限不足'; return; fi
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' 2>/dev/null || true
  echo 'High-risk container settings / 高风险容器配置:'
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    docker inspect --format '{{.Name}} privileged={{.HostConfig.Privileged}} network={{.HostConfig.NetworkMode}} pid={{.HostConfig.PidMode}} mounts={{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$id" 2>/dev/null || true
  done < <(docker ps -q 2>/dev/null)
}
