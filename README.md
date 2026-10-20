# VPS Guard

**中文** | [English](README.en.md)

Ubuntu/Debian VPS 的基础检查与管理工具。菜单包含只读检查和需确认的系统操作。

## 功能

1. **VPS 信息审计**：汇总系统、CPU、内存、磁盘、SSH、防火墙、端口、用户、服务、Docker 和软件更新信息；只读。
2. **SSH / 防火墙**：查看 SSH 与 UFW 状态、管理 SSH 端口和 UFW 规则，并提供 SSH 端口 `20001` 与基础 UFW 规则的快捷设置。
3. **IPv6 状态与配置**：检查本机 IPv6 状态，并可启用本机 IPv6 与 UFW IPv6 支持。
4. **BBR / fq 状态与配置**：查看拥塞控制状态，并可启用 BBR 与 fq。
5. **软件与内核更新**：预览 APT 软件更新，并执行 `apt-get update` 和 `apt-get upgrade`；不自动重启。
6. **服务管理**：查看常用 systemd 服务，并启动、停止、重启或重载服务。
7. **监听端口检查**：查看 TCP/UDP 监听、地址族、绑定地址和进程。
8. **Fail2Ban 管理**：查看 Jail 与封禁 IP、解封 IP、查看日志。
9. **用户与 SSH 密钥**：列出用户、创建普通用户、加入 sudo 组、添加 SSH 公钥；可在检查公钥登录后关闭 root 密码登录。
10. **资源监控**：查看负载、内存、磁盘、inode 和高占用进程；只读。
11. **日志查看**：查看 SSH、Fail2Ban、UFW 和服务错误日志；只读，不写报告文件。
12. **Docker 管理**：查看容器及端口映射，启动、停止或重启容器。
13. **定时任务管理**：查看 systemd timers，新增或删除 root 用户的 Cron 任务。
14. **安全清理**：预览并清理 APT 缓存、systemd 日志、已停止容器或悬空 Docker 镜像。
15. **网络安全检查**：查看地址、路由、DNS、公网 IP，并提示检查云厂商安全组；只读。
16. **配置状态导出**：将 SSH、UFW、Fail2Ban 和 Docker 状态输出到终端，不创建文件。

## 运行

在项目目录执行菜单：

```bash
sudo bash vps-guard.sh ui
```

命令行检查与建议：

```bash
sudo bash vps-guard.sh audit
sudo bash vps-guard.sh audit en
sudo bash vps-guard.sh plan
```

安装后菜单退出不会删除程序，可直接再次运行：

```bash
sudo bash /opt/vps-guard/vps-guard.sh ui
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/CharlesField19/vps-guard/main/install.sh | sudo bash
```

默认安装到 `/opt/vps-guard` 并打开菜单。再次运行安装命令会覆盖升级现有安装，安装器不会创建目录备份。

## 注意事项

- 需要 root 权限；目前主要支持 Ubuntu/Debian 和 APT。
- 建议先运行信息审计。修改系统状态的操作需输入 `APPLY` 确认。
- SSH、防火墙和网络设置可能导致远程失联。操作前确认 VPS 控制台或救援入口可用；修改 SSH 端口后，先从第二个终端验证新端口登录，再考虑移除旧规则。
- 工具不自动备份或回滚配置。执行清理操作前仔细检查预览；清理的数据可能无法恢复。
- 更新不会自动重启；更新完成后请检查系统是否要求重启。
