#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds)
#

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-2]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-2]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 工具：包存在就强制写进 .config（避免 defconfig 收敛掉你的选择）
# -----------------------------------------------------------------------------
enable_pkg_if_exists() {
  local pkg="$1"
  if grep -R -n -m1 "define Package/${pkg}" feeds package 2>/dev/null | head -n1 >/dev/null; then
    sed -i "/^# CONFIG_PACKAGE_${pkg}=is not set$/d" .config 2>/dev/null || true
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null || true
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    log "Enable package: ${pkg}"
    return 0
  else
    warn "Package not found (skip): ${pkg}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 1) 保底：你需要的中文包 & TurboACC 中文包
# -----------------------------------------------------------------------------
enable_pkg_if_exists "luci-i18n-base-zh-cn" || true
enable_pkg_if_exists "luci-i18n-opkg-zh-cn" || true
enable_pkg_if_exists "luci-i18n-firewall-zh-cn" || true

# TurboACC(mtk) 中文
enable_pkg_if_exists "luci-i18n-turboacc-mtk-zh-cn" || true

# 你 .config 里写了 luci-app-autoreboot-zh-cn（大概率不存在），这里兜底正确包名
enable_pkg_if_exists "luci-i18n-autoreboot-zh-cn" || true

# 收敛配置（让依赖展开）
make defconfig >/dev/null 2>&1 || true
log "make defconfig done (best-effort)"

# -----------------------------------------------------------------------------
# 2) sysctl 调优（你原先那份很长，这里保留关键项；想全量也可替换回去）
# -----------------------------------------------------------------------------
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-sysctl-tune.conf << 'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=2048

net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait=60
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=300
EOF
log "sysctl tune written."

# -----------------------------------------------------------------------------
# 3) 关键修复：首次启动强制 LuCI 中文（禁止 auto）+ 清缓存
#    这一步会彻底解决 TurboACC 明明有中文包却显示英文的问题
# -----------------------------------------------------------------------------
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-force-luci-zhcn << 'EOF'
#!/bin/sh
# Force LuCI language to zh_cn (DO NOT use 'auto'), and clear caches so i18n applies.

uci -q set luci.main.lang='zh_cn'
uci -q commit luci

rm -rf /tmp/luci-* /tmp/luci-indexcache 2>/dev/null

exit 0
EOF
chmod +x files/etc/uci-defaults/99-force-luci-zhcn
log "uci-defaults wrote: luci.main.lang=zh_cn + clear cache"

log "diy-part2 done."
