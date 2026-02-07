#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds)
#

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-2]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-2]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 工具：如果包存在，就把它强制写进 .config（避免你明明想要但没进固件）
# -----------------------------------------------------------------------------
enable_pkg_if_exists() {
  local pkg="$1"
  if grep -R -n -m1 "define Package/${pkg}" feeds package 2>/dev/null | head -n1 >/dev/null; then
    sed -i "/^# CONFIG_PACKAGE_${pkg}=is not set$/d" .config 2>/dev/null || true
    # 如果之前写成 m 或 y 都不管，最终 defconfig 会收敛
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
# 1) 自动选择可用的 LuCI 主题：argonv3 -> argon -> bootstrap
# -----------------------------------------------------------------------------
choose_theme_pkg() {
  local candidates=("luci-theme-argonv3" "luci-theme-argon" "luci-theme-bootstrap")
  local chosen="luci-theme-bootstrap"
  for pkg in "${candidates[@]}"; do
    if grep -R -n -m1 "define Package/${pkg}" feeds package 2>/dev/null | head -n1 >/dev/null; then
      chosen="$pkg"
      break
    fi
  done
  echo "$chosen"
}

THEME_PKG="$(choose_theme_pkg)"
THEME_DIR="${THEME_PKG#luci-theme-}"
log "Selected LuCI theme: ${THEME_PKG} (dir: ${THEME_DIR})"

# 让 luci 元包默认依赖使用选中的主题（如果是 bootstrap 就不动）
LUCICOL_MK="feeds/luci/collections/luci/Makefile"
if [[ -f "$LUCICOL_MK" && "$THEME_PKG" != "luci-theme-bootstrap" ]]; then
  sed -i "s/luci-theme-bootstrap/${THEME_PKG}/g" "$LUCICOL_MK" || true
  log "Patched: feeds/luci/collections/luci/Makefile theme dependency -> ${THEME_PKG}"
fi

# -----------------------------------------------------------------------------
# 2) 强制启用：LuCI + TurboACC(mtk) + 中文包
#    重点：你现在问题的根源是 luci.main.lang=auto，所以必须强制 zh_cn
# -----------------------------------------------------------------------------
# LuCI 与常用组件（按需增减）
enable_pkg_if_exists "luci" || true
enable_pkg_if_exists "luci-ssl" || true

# TurboACC(mtk) + 中文（你已验证这套包名是正确的）
enable_pkg_if_exists "luci-app-turboacc-mtk" || true
enable_pkg_if_exists "luci-i18n-turboacc-mtk-zh-cn" || true

# LuCI 常用中文翻译（确保系统中文环境齐全）
enable_pkg_if_exists "luci-i18n-base-zh-cn" || true
enable_pkg_if_exists "luci-i18n-opkg-zh-cn" || true
enable_pkg_if_exists "luci-i18n-firewall-zh-cn" || true

# 主题本体也兜底写进 config
enable_pkg_if_exists "${THEME_PKG}" || true

# 收敛配置
make defconfig >/dev/null 2>&1 || true
log "make defconfig done (best-effort)"

# -----------------------------------------------------------------------------
# 3) sysctl 调优（刷入固件，开机生效）
# -----------------------------------------------------------------------------
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-sysctl-tune.conf << 'EOF'
############################################
# Queue / Congestion Control
############################################
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

############################################
# Backlog
############################################
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=2048

############################################
# Conntrack
############################################
net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait=60
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=300
EOF
log "sysctl tune written."

# -----------------------------------------------------------------------------
# 4) 首次启动：强制 LuCI 中文 + 主题 + 清缓存（确保 TurboACC 翻译立即生效）
# -----------------------------------------------------------------------------
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-luci-zhcn-theme << EOF
#!/bin/sh
# Force LuCI language/theme on first boot, and clear caches so i18n applies.
# Key fix: DO NOT use 'auto'. Force 'zh_cn'.

uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/${THEME_DIR}'
uci -q commit luci

rm -rf /tmp/luci-* /tmp/luci-indexcache 2>/dev/null

exit 0
EOF
chmod +x files/etc/uci-defaults/99-luci-zhcn-theme
log "uci-defaults wrote: lang=zh_cn (fix auto), theme=/luci-static/${THEME_DIR}, clear cache"

log "diy-part2 done."
