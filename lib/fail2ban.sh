#!/usr/bin/env bash

fail2ban_jail_names() {
  sed -n 's/^.*Jail list:[[:space:]]*//p' | tail -n 1 | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
}
