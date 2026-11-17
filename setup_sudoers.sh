#!/bin/bash
# 配置 sudo 免密规则，使 MySQL 控制面板启停服务时不再弹出密码框。
# 用法（需要输入一次管理员密码）：
#   ./setup_sudoers.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

FILE=/etc/sudoers.d/mysql-prefpane

cat > "$FILE" <<'EOF'
# MySQL 控制面板（MySQL.prefPane）免密规则：仅允许管理员组免密执行以下管理命令
%admin ALL=(root) NOPASSWD: /bin/launchctl bootstrap system /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
%admin ALL=(root) NOPASSWD: /bin/launchctl bootout system/com.oracle.oss.mysql.mysqld
%admin ALL=(root) NOPASSWD: /bin/launchctl kickstart system/com.oracle.oss.mysql.mysqld
%admin ALL=(root) NOPASSWD: /bin/launchctl kickstart -k system/com.oracle.oss.mysql.mysqld
%admin ALL=(root) NOPASSWD: /usr/local/mysql/support-files/mysql.server
EOF

chmod 440 "$FILE"
chown root:wheel "$FILE"
visudo -c -f "$FILE"

echo "已写入 $FILE，控制面板启停 MySQL 将不再提示密码。"
echo "如需恢复每次输入密码，执行：sudo rm $FILE"
