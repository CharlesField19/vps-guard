#!/usr/bin/env bash
LANGUAGE=${LANGUAGE:-zh}

msg() {
  case "$LANGUAGE:$1" in
    zh:app) echo 'VPS Guard VPS 安全管理工具' ;; en:app) echo 'VPS Guard VPS Security Tool' ;;
    zh:audit) echo '只读安全审计' ;; en:audit) echo 'Read-only security audit' ;;
    zh:system) echo '系统信息' ;; en:system) echo 'System information' ;;
    zh:ssh) echo 'SSH 安全' ;; en:ssh) echo 'SSH security' ;;
    zh:firewall) echo '防火墙与监听端口' ;; en:firewall) echo 'Firewall and listening ports' ;;
    zh:services) echo '安全服务' ;; en:services) echo 'Security services' ;;
    zh:users) echo '用户与登录' ;; en:users) echo 'Users and logins' ;;
    zh:docker) echo 'Docker 暴露情况' ;; en:docker) echo 'Docker exposure' ;;
    zh:resources) echo '内核与资源' ;; en:resources) echo 'Kernel and resources' ;;
    zh:updates) echo '系统更新' ;; en:updates) echo 'System updates' ;;
    zh:baseline) echo '基础安全基线' ;; en:baseline) echo 'Basic security baseline' ;;
    zh:risk) echo '风险' ;; en:risk) echo 'RISK' ;;
    zh:ok) echo '正常' ;; en:ok) echo 'OK' ;;
    zh:warn) echo '注意' ;; en:warn) echo 'WARNING' ;;
    zh:no_change) echo '审计完成：未修改配置，未创建报告文件。' ;; en:no_change) echo 'Audit complete: no configuration changed and no report file was created.' ;;
    zh:recommend) echo '安全加固建议' ;; en:recommend) echo 'Hardening recommendations' ;;
    zh:key_missing) echo '未发现有效 SSH 公钥；暂时不能关闭密码登录。' ;; en:key_missing) echo 'No usable SSH public key found; password login must not be disabled yet.' ;;
    zh:root_password) echo 'root 密码登录已启用。' ;; en:root_password) echo 'Root password login is enabled.' ;;
    zh:validated) echo '配置验证通过' ;; en:validated) echo 'Configuration validation passed' ;;
    zh:cancel) echo '已取消，未修改系统。' ;; en:cancel) echo 'Cancelled; no system changes made.' ;;
    *) echo "$1" ;;
  esac
}
say() { printf '%s\n' "$(msg "$1")"; }
heading() { printf '\n===== %s =====\n' "$(msg "$1")"; }
pass() { printf '[%s] %s\n' "$(msg ok)" "$*"; }
notice() { printf '[%s] %s\n' "$(msg warn)" "$*"; }
danger() { printf '[%s] %s\n' "$(msg risk)" "$*"; }
