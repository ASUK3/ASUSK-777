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

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-1]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-1]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 1) 编译时默认：IP / 主机名 / 时区 / NTP（改 config_generate）
# -----------------------------------------------------------------------------
CFG_GEN="package/base-files/files/bin/config_generate"
if [[ -f "$CFG_GEN" ]]; then
  # 1.1 强制默认 LAN IP -> 192.168.6.1
  # 优先改 ipaddr:-"x" 这一类写法（最精准）
  sed -i \
    -e 's/ipaddr:-"192\.168\.[0-9]\{1,3\}\.1"/ipaddr:-"192.168.6.1"/g' \
    -e 's/"192\.168\.1\.1"/"192.168.6.1"/g' \
    "$CFG_GEN"
  log "Default LAN IP -> 192.168.6.1"

  # 1.2 强制主机名 -> ASUSWRT（更稳：直接改 hostname 行，不依赖默认值）
  sed -i -E "s/(hostname=)'[^']*'/\1'ASUSWRT'/g" "$CFG_GEN"
  log "Hostname -> ASUSWRT"

  # 1.3 时区：CST-8 + Asia/Shanghai
  sed -i \
    -e "s/timezone='UTC'/timezone='CST-8'/g" \
    -e "s/zonename='UTC'/zonename='Asia\\/Shanghai'/g" \
    "$CFG_GEN"
  log "Timezone -> CST-8 / Asia/Shanghai"

  # 1.4 NTP：尽量替换默认池（可能因分支差异替换不到，建议在 diy2 用 uci-defaults 强制）
  sed -i \
    -e "s/server='0\\.openwrt\\.pool\\.ntp\\.org 1\\.openwrt\\.pool\\.ntp\\.org 2\\.openwrt\\.pool\\.ntp\\.org 3\\.openwrt\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/server='0\\.pool\\.ntp\\.org 1\\.pool\\.ntp\\.org 2\\.pool\\.ntp\\.org 3\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/pool\\.ntp\\.org/cn\\.pool\\.ntp\\.org/g" \
    "$CFG_GEN" || true
  log "NTP prefer CN servers (best-effort in config_generate)"
else
  warn "Not found: $CFG_GEN (skip config_generate edits)"
fi

# -----------------------------------------------------------------------------
# 2) 默认主题（argonv3）
# 注意：part1 阶段 feeds 可能还没 update，文件可能不存在。
# 最稳做法：在 diy-part2.sh 再做一次同样的替换兜底。
# -----------------------------------------------------------------------------
LUCICOL_MK="feeds/luci/collections/luci/Makefile"
if [[ -f "$LUCICOL_MK" ]]; then
  sed -i 's/luci-theme-bootstrap/luci-theme-argonv3/g' "$LUCICOL_MK" || true
  log "Force LuCI default theme: luci-theme-argonv3"
else
  warn "Not found: $LUCICOL_MK (feeds not updated yet). Recommend repeating this in diy-part2.sh."
fi

log "diy-part1 done."
