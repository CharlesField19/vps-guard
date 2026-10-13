#!/usr/bin/env bash
audit_all() {
  say audit
  audit_system
  audit_ssh
  audit_network
  audit_services
  audit_users
  audit_docker
  audit_resources
  audit_baseline
  heading updates
  if have apt-get; then apt-get -s full-upgrade 2>/dev/null | tail -n 8; fi
  say no_change
}
