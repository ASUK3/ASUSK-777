#!/bin/bash
#
# OpenWrt DIY script part 1 (Before Update feeds)
#

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-1]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-1]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 1) 编译时默认：IP / 主机名 / 时区 / NTP（改 config_generate）
# -----------------------------------------------------------------------------
CFG_GEN="package/base-files/files/bin/config_generate"
if [[ -f "$CFG_GEN" ]]; then
  # 默认 LAN IP -> 192.168.6.1
  sed -i -E \
    -e 's/(ipaddr:-)"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"/\1"192.168.6.1"/g' \
    "$CFG_GEN" || true
  log "Default LAN IP -> 192.168.6.1"

  # 主机名 -> ASUSWRT
  sed -i -E "s/(hostname=)'[^']*'/\1'ASUSWRT'/g" "$CFG_GEN" || true
  log "Hostname -> ASUSWRT"

  # 时区：CST-8 + Asia/Shanghai
  sed -i \
    -e "s/timezone='UTC'/timezone='CST-8'/g" \
    -e "s/zonename='UTC'/zonename='Asia\\/Shanghai'/g" \
    "$CFG_GEN" || true
  log "Timezone -> CST-8 / Asia/Shanghai"

  # NTP：尽量替换默认池（best-effort）
  sed -i \
    -e "s/server='0\\.openwrt\\.pool\\.ntp\\.org 1\\.openwrt\\.pool\\.ntp\\.org 2\\.openwrt\\.pool\\.ntp\\.org 3\\.openwrt\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/server='0\\.pool\\.ntp\\.org 1\\.pool\\.ntp\\.org 2\\.pool\\.ntp\\.org 3\\.pool\\.ntp\\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" \
    -e "s/pool\\.ntp\\.org/cn\\.pool\\.ntp\\.org/g" \
    "$CFG_GEN" || true
  log "NTP prefer CN servers (best-effort)"
else
  warn "Not found: $CFG_GEN (skip config_generate edits)"
fi

log "diy-part1 done."
