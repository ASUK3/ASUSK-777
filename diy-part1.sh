#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default
#!/bin/bash
# OpenWrt DIY script part 1 (Before Update feeds)

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-1]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-1]\033[0m $*"; }

# 1) 强制默认主题：luci collection 里把 bootstrap 替换成 argonv3
LUCICOL_MK="feeds/luci/collections/luci/Makefile"
if [[ -f "$LUCICOL_MK" ]]; then
  sed -i 's/luci-theme-bootstrap/luci-theme-argonv3/g' "$LUCICOL_MK" || true
  log "Force LuCI default theme: luci-theme-argonv3"
else
  warn "Not found: $LUCICOL_MK (feeds not prepared yet?)"
fi

# 2) 强制默认 IP / 主机名 / 时区 / NTP（编译时默认）
CFG_GEN="package/base-files/files/bin/config_generate"
if [[ -f "$CFG_GEN" ]]; then
  # 2.1 默认 IP：只改匹配到的默认值（避免误伤其它文本）
  sed -i \
    -e 's/ipaddr:-"192\.168\.[0-9]\{1,3\}\.1"/ipaddr:-"192.168.6.1"/g' \
    -e 's/"192\.168\.[0-9]\{1,3\}\.1"/"192.168.6.1"/g' \
    "$CFG_GEN"
  log "Default LAN IP -> 192.168.6.1"

  # 2.2 主机名：强制 ASUSWRT（只替换 hostname 行更稳）
  sed -i "s/hostname='ImmortalWrt'/hostname='ASUSWRT'/g" "$CFG_GEN"
  log "Hostname -> ASUSWRT"

  # 2.3 时区：CST-8 + Asia/Shanghai（LuCI 显示更规范）
  sed -i \
    -e "s/timezone='UTC'/timezone='CST-8'/g" \
    -e "s/zonename='UTC'/zonename='Asia\\/Shanghai'/g" \
    "$CFG_GEN"
  log "Timezone -> CST-8 / Asia/Shanghai"

  # 2.4 NTP：替换成国内更快、更稳的一组（多源容错）
  # 说明：真正“最快”取决于你网络/运营商/地区，最实用是放多台国内优质 NTP，让系统自己选可用/低延迟的。
  # 常见默认写法两种：openwrt.pool 或 pool.ntp.org，这里都兼容替换。
  sed -i \
    -e "s/server='0\\.openwrt\\.pool\\.ntp\\.org 1\\.openwrt\\.pool\\.ntp\\.org 2\\.openwrt\\.pool\\.ntp\\.org 3\\.openwrt\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/server='0\\.pool\\.ntp\\.org 1\\.pool\\.ntp\\.org 2\\.pool\\.ntp\\.org 3\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/pool\\.ntp\\.org/cn\\.pool\\.ntp\\.org/g" \
    "$CFG_GEN" || true
  log "NTP -> Aliyun / Tencent / TUNA / NTSC / cn.pool"
else
  warn "Not found: $CFG_GEN (skip config_generate edits)"
fi

log "diy-part1 done."
