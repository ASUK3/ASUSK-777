#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds)
#

set -euo pipefail

log()  { echo -e "\033[1;32m[DIY-2]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-2]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 工具：往 .config 里“强制启用”某个包（不存在则跳过，不会把编译搞炸）
# -----------------------------------------------------------------------------
enable_pkg_if_exists() {
  local pkg="$1"
  # feeds / package 里只要存在其 Makefile 定义就认为可用
  if grep -R -n -m1 "define Package/${pkg}" feeds package 2>/dev/null | head -n1 >/dev/null; then
    # 先移除可能存在的 is not set 行，避免冲突
    sed -i "/^# CONFIG_PACKAGE_${pkg}=is not set$/d" .config 2>/dev/null || true
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
log "Selected LuCI theme package: ${THEME_PKG}"

# 替换 luci collection 默认主题依赖
LUCICOL_MK="feeds/luci/collections/luci/Makefile"
if [[ -f "$LUCICOL_MK" ]]; then
  if [[ "$THEME_PKG" != "luci-theme-bootstrap" ]]; then
    sed -i "s/luci-theme-bootstrap/${THEME_PKG}/g" "$LUCICOL_MK" || true
    log "Patched ${LUCICOL_MK}: luci-theme-bootstrap -> ${THEME_PKG}"
  else
    log "Keep default theme dependency: luci-theme-bootstrap"
  fi
else
  warn "Not found: ${LUCICOL_MK} (skip theme dependency patch)"
fi

# -----------------------------------------------------------------------------
# 2) 强制把中文语言包、TurboACC 中文包加入固件（避免“只编译没打进镜像”）
#    重点：TurboACC MTK 对应 i18n 包通常是 luci-i18n-turboacc-mtk-zh-cn
# -----------------------------------------------------------------------------
# 先确保基础中文（很多页面翻译依赖它）
enable_pkg_if_exists "luci-i18n-base-zh-cn" || true
enable_pkg_if_exists "luci-i18n-opkg-zh-cn" || true
enable_pkg_if_exists "luci-i18n-firewall-zh-cn" || true

# TurboACC：优先 mtk 版本中文包，其次尝试非 mtk 名字（防不同源码树）
if ! enable_pkg_if_exists "luci-i18n-turboacc-mtk-zh-cn"; then
  enable_pkg_if_exists "luci-i18n-turboacc-zh-cn" || true
fi

# 主题本体也最好写进 .config（即便 Makefile 替换依赖，这里再兜底）
enable_pkg_if_exists "${THEME_PKG}" || true

# 让 .config 生效（重要：把上面 echo 的配置转成最终依赖）
make defconfig >/dev/null 2>&1 || true
log "make defconfig done (best-effort)"

# -----------------------------------------------------------------------------
# 3) TCP / 网络 / 内存 调度优化（sysctl.d，刷入固件，开机生效）
# -----------------------------------------------------------------------------
mkdir -p files/etc/sysctl.d

cat > files/etc/sysctl.d/99-sysctl-tune.conf << 'EOF'
############################################
# Queue / Congestion Control (BBR + FQ)
############################################
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

############################################
# Connection / Backlog
############################################
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=2048

############################################
# Socket Buffer
############################################
net.core.rmem_default=131072
net.core.wmem_default=131072
net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.ipv4.tcp_rmem=4096 131072 8388608
net.ipv4.tcp_wmem=4096 131072 8388608

############################################
# TCP Behavior
############################################
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fastopen=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_limit_output_bytes=131072
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_retries2=10
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_rto_min=200
net.ipv4.tcp_ecn=0

############################################
# Keepalive
############################################
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5

############################################
# UDP
############################################
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384

############################################
# Busy Poll (CPU trade-off)
############################################
net.core.busy_read=50
net.core.busy_poll=50

############################################
# Security / Redirects
############################################
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

############################################
# IPv6 (gateway mode)
############################################
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.use_tempaddr=0
net.ipv6.conf.default.use_tempaddr=0

net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh3=8192

############################################
# Conntrack
############################################
net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait=60
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=300
EOF
log "Wrote sysctl tune: files/etc/sysctl.d/99-sysctl-tune.conf"

# -----------------------------------------------------------------------------
# 4) 首次启动：强制 LuCI 主题 + 强制 LuCI 语言为中文（解决 TurboACC 仍英文）
# -----------------------------------------------------------------------------
mkdir -p files/etc/uci-defaults

THEME_DIR="${THEME_PKG#luci-theme-}"

cat > files/etc/uci-defaults/99-luci-init << EOF
#!/bin/sh
# Force LuCI theme + language on first boot

# 主题
uci -q set luci.main.mediaurlbase='/luci-static/${THEME_DIR}'

# 语言：强制 zh_cn（不靠浏览器 Accept-Language）
uci -q set luci.main.lang='zh_cn'

uci -q commit luci
exit 0
EOF

chmod +x files/etc/uci-defaults/99-luci-init
log "Wrote uci-defaults: theme=/luci-static/${THEME_DIR}, lang=zh_cn"

log "diy-part2 done."
