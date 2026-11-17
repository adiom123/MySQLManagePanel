# MySQL 控制面板（macOS 系统设置面板）

参考 [MySQL-prefPane](https://github.com/adiom123/MySQL-prefPane)（MIT 许可）使用现代 API 重写，
适配 macOS 27 与 MySQL 26.10.0，全中文界面。

## 功能

- 开/关切换：启动 / 停止 MySQL 服务；重启服务按钮
- 运行状态实时显示（每 3 秒自动刷新）
- 可设置 MySQL 安装位置（默认 `/usr/local/mysql`），自动显示 `mysqld --version` 版本信息
- 自动识别服务管理方式：
  - 存在 `/Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist` 时（官方 dmg 安装的默认方式），
    通过 `launchctl bootstrap / bootout / kickstart` 管理（mysql.server 与 launchd 的 pid 文件路径
    不一致，用 mysql.server 无法停止 launchd 启动的 mysqld）
  - 否则使用 `<安装位置>/support-files/mysql.server start|stop|restart`

## 免密配置（可选，推荐）

默认每次启停会弹一次系统密码框。执行一次以下脚本后永久免密：

```bash
./setup_sudoers.sh   # 会要求输入一次管理员密码
```

脚本写入 `/etc/sudoers.d/mysql-prefpane`，仅放行上述几条管理命令（`visudo` 校验）。
如需恢复密码提示：`sudo rm /etc/sudoers.d/mysql-prefpane`

注意：`~/Documents` 等目录受 TCC 保护，提权进程无法直接执行其中的脚本，
若在密码框后报 "Operation not permitted"，请把脚本复制到 `/tmp` 再运行，
或在「终端」App 中直接运行（终端拥有完全磁盘访问权限时不受限）。

## 技术说明

- 旧参考项目使用的 `AuthorizationExecuteWithPrivileges` 已被 Apple 移除。
  本项目优先使用 `sudo -n`（配合 sudoers 免密规则，无任何提示）；
  未配置免密时回退到 `NSAppleScript` 的 `do shell script ... with administrator privileges`（弹系统密码框）。
- 界面完全用代码构建（无 xib），避免旧版 nib 兼容问题。
- 状态检测使用 `pgrep -x mysqld`。
- 安装位置保存在 `~/Library/Preferences/com.zhaozc.MySQLPrefPane.plist`。

## 构建

本机只需命令行工具（Command Line Tools），无需完整 Xcode：

```bash
./build.sh
```

产物：`build/MySQL.prefPane`（arm64 + x86_64 通用，ad-hoc 签名）

## 安装

双击 `build/MySQL.prefPane`，或手动复制：

```bash
cp -R build/MySQL.prefPane ~/Library/PreferencePanes/
open ~/Library/PreferencePanes/MySQL.prefPane
```

之后可在 系统设置 中搜索 "MySQL" 打开面板。

## 卸载

```bash
rm -rf ~/Library/PreferencePanes/MySQL.prefPane
# 可选：移除免密规则
sudo rm /etc/sudoers.d/mysql-prefpane
```
