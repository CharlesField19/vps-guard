# VPS Guard

一个简单的 Ubuntu/Debian VPS 基础检查和设置工具。

## 功能

启动菜单后可以选择：

1. **VPS 信息审计**：查看系统、CPU、内存、磁盘、SSH、防火墙、端口、用户、服务、Docker 和更新信息。只读，不修改系统。
2. **SSH / 防火墙**：查看状态，或设置 SSH 端口 `20001`，并放行 `20001`、`80`、`443`。
3. **IPv6**：查看状态，确认后启用本机 IPv6 支持。
4. **BBR / fq**：查看状态，确认后启用 BBR 和 fq。
5. **软件与内核更新**：先显示更新预览，确认后执行更新，不自动重启。

## 使用

直接运行：

```bash
cd /opt/vps-guard && sudo bash vps-guard.sh ui
```

命令行方式：

```bash
sudo bash vps-guard.sh audit
sudo bash vps-guard.sh audit en
sudo bash vps-guard.sh plan
sudo bash vps-guard.sh rollback
```

## 一键安装


```bash
curl -fsSL https://raw.githubusercontent.com/CharlesField19/vps-guard/main/install.sh | sudo bash
```

安装到 `/opt/vps-guard` 后会自动打开菜单。

## 注意

- 第一次建议先选择信息审计。
- SSH 和防火墙设置可能导致远程断开，操作前应确保有 VPS 控制台或救援入口。
- 设置 SSH 端口后，必须从第二个终端确认 `20001` 可以登录，再清理旧端口规则。
- 需要 root 权限；当前主要支持 Ubuntu/Debian 和 APT。
- 更新完成后不会自动重启。
- 配置修改前会备份到 `/var/lib/vps-guard`，失败时会尝试恢复。
