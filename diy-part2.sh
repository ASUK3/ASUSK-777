#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# ===== 强制使用 BBR（写入固件：sysctl.d + uci-defaults 双保险）=====

# 1) sysctl.d：每次开机都会加载（最推荐）
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-bbr.conf << 'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# 2) uci-defaults：首次启动再“拉一遍”，防止被别的包覆盖（可选但很稳）
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-bbr << 'EOF'
#!/bin/sh
sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
exit 0
EOF
chmod +x files/etc/uci-defaults/99-bbr
