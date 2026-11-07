# VPS Guard

**中文** | [English](README.en.md)

Ubuntu/Debian VPS 的基础检查与管理工具。本文不只列出菜单名称，也说明每项功能解决什么问题、会读取或更改哪些内容，以及使用时应留意什么。只读检查不会更改系统；修改系统的菜单操作通常会先展示目标，并要求输入 `y` 确认或 `n` 取消（不区分大小写）。

## 菜单与脚本入口对照

| 主菜单选项 | 对应脚本动作 | 类型 |
| --- | --- | --- |
| 1 信息审计 | `audit_all`：系统、SSH、网络、防火墙/监听、服务、用户、Docker、资源、基线检查及 APT `full-upgrade` 模拟末尾 | 只读 |
| 2 SSH / 防火墙 | 进入 SSH/防火墙子菜单：状态、端口/socket、20001 快捷设置、UFW 规则 | 查看/配置 |
| 3 IPv6 | 查看接口/sysctl/UFW IPv6 状态；子选项 1 启用 | 查看/配置 |
| 4 BBR / fq | 查看当前算法、可用算法和队列规则；子选项 1 启用 | 查看/配置 |
| 5 更新 | 模拟 `apt-get upgrade`；输入 `y` 后执行 `apt-get update` + `apt-get upgrade -y` | 更新 |
| 6 服务 | 固定列出 9 个服务并对选中项查看/启动/停止/重启/重载 | 查看/控制 |
| 7 监听端口 | `ss -H -tulpen` 并标注全地址、回环或指定地址监听 | 只读 |
| 8 Fail2Ban | 查看 Jail/封禁 IP、解封 IP、查看日志 | 查看/配置 |
| 9 用户/密钥 | 列用户和 sudo、创建用户、添加公钥、关闭 root 密码认证 | 查看/配置 |
| 10 资源 | 输出 load、内存、磁盘、inode、CPU/内存占用进程 | 只读 |
| 11 日志 | SSH、Fail2Ban、UFW 拒绝相关内核日志、错误级别日志 | 只读 |
| 12 Docker | 列出容器、启动/停止/重启、查看限行日志；可对运行容器测试 Nginx 配置，测试通过并确认后 reload | 查看/控制 |
| 13 定时任务 | 列出 timers，查看/新增/删除 root crontab 行 | 查看/配置 |
| 14 清理 | APT 缓存、systemd journal、停止容器、悬空镜像 | 清理 |
| 15 网络检查 | 地址、路由、DNS、公网 IPv4/IPv6 查询 | 只读 |
| 16 状态导出 | SSH/网络审计、Fail2Ban 状态、运行中 Docker 摘要打印到终端 | 只读输出 |
| 17 扩展诊断 | 大目录用量、失败服务/重启提示、HTTP/TLS、有限时路由追踪 | 只读/可选网络请求 |

以下章节进一步按脚本子菜单选项解释具体动作；主菜单 `0` 退出。

## 菜单功能详解

各菜单项的具体动作、读取或修改的内容以及风险说明见 [docs/menu.md](docs/menu.md)。

## 项目结构与开发

- `vps-guard.sh`：入口、参数分发和模块加载。
- `lib/`：可复用的 SSH、密钥、网络、UFW 和 Fail2Ban 辅助函数。
- `modules/audit/`：只读审计；`modules/harden/`：系统加固；`modules/ui/`：交互菜单。
- `tests/`：回归测试、命令 mock 和测试运行器。

开发与测试说明见 [docs/architecture.md](docs/architecture.md) 和 [docs/testing.md](docs/testing.md)。SSH 或防火墙失联时的救援步骤见 [docs/recovery.md](docs/recovery.md)。

```bash
make check    # 语法检查 + 回归测试
make lint     # 需要 shellcheck
```

版本号和变更记录见 `VERSION`、`CHANGELOG.md`；安全报告方式见 `SECURITY.md`。

## 运行

在项目目录执行交互菜单：

```bash
sudo bash vps-guard.sh ui
```

命令行审计（可选中文或英文）及建议：

```bash
sudo bash vps-guard.sh audit
sudo bash vps-guard.sh audit en
sudo bash vps-guard.sh plan
```

安装后退出菜单不会删除程序，可直接再次运行：

```bash
sudo bash /opt/vps-guard/vps-guard.sh ui
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/CharlesField19/vps-guard/main/install.sh | sudo bash
```

默认安装到 `/opt/vps-guard` 并打开菜单。再次运行安装命令会先把现有目录备份到 `/var/backups/vps-guard/<时间戳>`，再覆盖升级。安装器拒绝 `/`、`/opt`、`/etc`、系统 bin/log 目录、`/tmp` 等危险路径。需要校验下载包时可设置 `VPS_GUARD_SHA256=<sha256>`，安装器会调用 `sha256sum -c`。自动化安装可设置 `VPS_GUARD_NO_UI=1`，安装完成后不打开菜单。

## 通用注意事项

- 需要 root 权限；目前主要面向 Ubuntu/Debian 和 APT 环境。部分功能需要对应软件/命令已安装（如 UFW、Fail2Ban、Docker、systemd）。
- 先运行信息审计了解当前状态。凡会修改系统状态的操作，输入 `y`（不区分大小写）确认，输入 `n` 或其他内容取消。
- SSH、防火墙及网络修改可能造成远程失联。操作前确认 VPS 控制台或救援入口可用；更改 SSH 端口后，先从第二个终端测试新端口登录，再手动考虑移除旧端口。
- 改 SSH 端口、关闭 root 密码登录，以及 20001 快捷设置，在验证或重载失败时会回滚本次 SSH 配置；快捷设置还会在默认策略修改失败时恢复原策略。其余更新、清理和账户操作仍不自动回滚。重要数据和配置应自行备份。
- 更新不自动重启；完成后检查系统是否要求重启。
