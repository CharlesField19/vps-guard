# VPS Guard

一个简单的 Ubuntu/Debian VPS 基础检查和设置工具。

## 功能

启动菜单后可以选择：

1. **VPS 信息审计**：查看系统、CPU、内存、磁盘、SSH、防火墙、端口、用户、服务、Docker 和更新信息。只读，不修改系统。
2. **SSH / 防火墙**：查看 SSH/防火墙状态，设置 SSH 与基础规则；UFW 管理支持新增/删除端口规则、启用/禁用防火墙及设置默认策略。
3. **IPv6**：查看状态，确认后启用本机 IPv6 支持。
4. **BBR / fq**：查看状态，确认后启用 BBR 和 fq。
5. **软件与内核更新**：先显示更新预览，输入 `APPLY` 后执行安全升级，不自动重启。
6. **服务管理**：查看并启动、停止、重启或重载常用 systemd 服务。
7. **监听端口检查**：查看 TCP/UDP、IPv4/IPv6、绑定地址和进程信息。
8. **Fail2Ban 管理**：查看 Jail、封禁 IP、解封 IP 和日志。
9. **用户与 SSH 密钥**：列出用户、创建用户、加入 sudo、添加 SSH 公钥。
10. **资源监控**：查看负载、内存、磁盘、inode 和高占用进程。
11. **日志查看**：查看 SSH、Fail2Ban、UFW 和系统错误日志，不写报告文件。
12. **Docker 管理**：查看容器和端口映射，启动、停止或重启容器。
13. **定时任务管理**：查看 systemd timers，添加或删除 root Cron 任务。
14. **安全清理**：预览并清理 APT 缓存、systemd 日志和 Docker 无用资源。
15. **网络安全检查**：查看地址、路由、DNS、公网 IP 和云安全组提醒。
16. **配置状态导出**：将 SSH、UFW、Fail2Ban、Docker 状态输出到终端，不创建文件。

## 使用

直接运行：

```bash
sudo bash vps-guard.sh ui
```

安装到 VPS 后，关闭菜单时不会删除程序。下次直接运行：

```bash
sudo bash /opt/vps-guard/vps-guard.sh ui
```

不需要重新下载。

命令行方式：

```bash
sudo bash vps-guard.sh audit
sudo bash vps-guard.sh audit en
sudo bash vps-guard.sh plan
```

## 一键安装


```bash
curl -fsSL https://raw.githubusercontent.com/CharlesField19/vps-guard/main/install.sh | sudo bash
```

安装到 `/opt/vps-guard` 后会自动打开菜单。再次执行安装命令时会覆盖升级现有程序，不会生成安装目录备份。

## 注意

- 第一次建议先选择信息审计。
- SSH 和防火墙设置可能导致远程断开，操作前应确保有 VPS 控制台或救援入口。
- 设置 SSH 端口后，必须从第二个终端确认 `20001` 可以登录，再清理旧端口规则。
- 需要 root 权限；当前主要支持 Ubuntu/Debian 和 APT。
- 更新完成后不会自动重启。
- 脚本不会自动备份或回滚配置；应用前请自行确认操作影响，并确保有 VPS 控制台或救援入口。
- 所有修改系统状态的确认口令统一为 `APPLY`。
