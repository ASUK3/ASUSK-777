#!/bin/bash
#
# OpenWrt DIY script part 2 (更新 feeds 后执行)
# 功能：启用中文语言包、强制 LuCI 中文显示、其他自定义配置
#

# 不使用 set -euo pipefail，避免命令未匹配时意外退出
# 改用手动错误处理，更稳健

log()  { echo -e "\033[1;32m[DIY-2]\033[0m $*"; }
warn() { echo -e "\033[1;33m[DIY-2 警告]\033[0m $*"; }
err()  { echo -e "\033[1;31m[DIY-2 错误]\033[0m $*"; }

# -----------------------------------------------------------------------------
# 工具函数：检查包是否存在于 feeds 或 package 中
# -----------------------------------------------------------------------------
check_pkg_exists() {
  local pkg="$1"
  # 在 feeds 和 package 目录中查找包定义
  if grep -R -l "define Package/${pkg}\b" feeds/ package/ 2>/dev/null | grep -q Makefile; then
    return 0
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 工具函数：如果包存在则强制启用（写入 .config）
# 作用：避免 make defconfig 收敛掉用户手动选择的包
# -----------------------------------------------------------------------------
enable_pkg_if_exists() {
  local pkg="$1"
  
  if check_pkg_exists "${pkg}"; then
    # 删除旧的配置行（无论是 =y 还是 is not set）
    sed -i "/^# CONFIG_PACKAGE_${pkg}=is not set$/d" .config 2>/dev/null || true
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null || true
    # 追加启用配置
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    log "✓ 已启用包: ${pkg}"
    return 0
  else
    warn "未找到包（跳过）: ${pkg}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# 检查当前工作目录
# -----------------------------------------------------------------------------
log "当前工作目录: $(pwd)"

if [[ ! -f ".config" ]]; then
  err "未找到 .config 文件！请确认脚本在 openwrt 源码根目录执行"
  exit 1
fi

if [[ ! -d "feeds" ]]; then
  warn "未找到 feeds 目录，包检查可能不准确"
fi

# -----------------------------------------------------------------------------
# 1) 启用中文语言包
# -----------------------------------------------------------------------------
log "========================================"
log ">>> 步骤 1：启用中文语言包"
log "========================================"

# 基础中文包（必备）
enable_pkg_if_exists "luci-i18n-base-zh-cn" || true
enable_pkg_if_exists "luci-i18n-opkg-zh-cn" || true
enable_pkg_if_exists "luci-i18n-firewall-zh-cn" || true

# TurboACC(mtk) 中文包
enable_pkg_if_exists "luci-i18n-turboacc-mtk-zh-cn" || true
# 兼容普通版 TurboACC
enable_pkg_if_exists "luci-i18n-turboacc-zh-cn" || true

# 自动重启中文包
enable_pkg_if_exists "luci-i18n-autoreboot-zh-cn" || true

# 其他常用中文包（可选，按需启用）
# enable_pkg_if_exists "luci-i18n-upnp-zh-cn" || true
# enable_pkg_if_exists "luci-i18n-ddns-zh-cn" || true
# enable_pkg_if_exists "luci-i18n-openvpn-zh-cn" || true
# enable_pkg_if_exists "luci-i18n-wireguard-zh-cn" || true
# enable_pkg_if_exists "luci-i18n-samba4-zh-cn" || true
# enable_pkg_if_exists "luci-i18n-minidlna-zh-cn" || true

# -----------------------------------------------------------------------------
# 收敛配置（让依赖关系自动展开）
# -----------------------------------------------------------------------------
log ">>> 执行 make defconfig 收敛配置..."
if make defconfig >/dev/null 2>&1; then
  log "✓ make defconfig 执行成功"
else
  warn "make defconfig 执行失败（非致命错误，继续执行）"
fi

# -----------------------------------------------------------------------------
# 2) 关键修复：首次启动强制 LuCI 中文 + 清理缓存
#    解决 TurboACC 等插件明明有中文包却显示英文的问题
# -----------------------------------------------------------------------------
log "========================================"
log ">>> 步骤 2：配置首次启动强制 LuCI 中文"
log "========================================"

# 创建 uci-defaults 目录
mkdir -p files/etc/uci-defaults

# 写入强制中文脚本
cat > files/etc/uci-defaults/99-force-luci-zhcn << 'UCI_EOF'
#!/bin/sh
# =============================================================================
# 功能：首次启动时强制设置 LuCI 语言为简体中文
# 说明：不使用 'auto' 自动检测，避免浏览器语言导致界面显示英文
# =============================================================================

# 设置 LuCI 语言为简体中文
uci -q set luci.main.lang='zh_cn'
uci -q commit luci

# 清理 LuCI 缓存，确保语言设置立即生效
rm -rf /tmp/luci-* /tmp/luci-indexcache 2>/dev/null

# 可选：设置系统语言环境
# export LANG=zh_CN.UTF-8
# export LC_ALL=zh_CN.UTF-8

exit 0
UCI_EOF

# 赋予执行权限
chmod +x files/etc/uci-defaults/99-force-luci-zhcn

if [[ -f "files/etc/uci-defaults/99-force-luci-zhcn" ]]; then
  log "✓ 已写入 uci-defaults 脚本: 99-force-luci-zhcn"
  log "  内容预览:"
  cat files/etc/uci-defaults/99-force-luci-zhcn | sed 's/^/    /'
else
  err "写入 uci-defaults 脚本失败"
fi

# -----------------------------------------------------------------------------
# 3) 可选：其他自定义配置
# -----------------------------------------------------------------------------
log "========================================"
log ">>> 步骤 3：其他自定义配置"
log "========================================"

# 示例：创建自定义 banner（可选）
mkdir -p files/etc
cat > files/etc/banner << 'BANNER_EOF'
 █████╗ ███████╗██╗   ██╗███████╗██╗    ██╗██████╗ ████████╗
██╔══██╗██╔════╝██║   ██║██╔════╝██║    ██║██╔══██╗╚══██╔══╝
███████║███████╗██║   ██║███████╗██║ █╗ ██║██████╔╝   ██║   
██╔══██║╚════██║██║   ██║╚════██║██║███╗██║██╔══██╗   ██║   
██║  ██║███████║╚██████╔╝███████║╚███╔███╔╝██║  ██║   ██║   
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   
-----------------------------------------------------
ImmortalWrt 24.10 | Kernel 6.6 | Build: $(date +%Y%m%d)
-----------------------------------------------------
BANNER_EOF
# log "✓ 已写入自定义 banner"

# 示例：修改 root 密码（可选，不推荐硬编码）
# 如需设置密码，建议在首次启动后通过 LuCI 或 passwd 命令设置

# -----------------------------------------------------------------------------
# 完成
# -----------------------------------------------------------------------------
log "========================================"
log "diy-part2 执行完毕"
log "========================================"

# 显示已启用的中文包配置
log "已启用的中文包配置:"
grep "CONFIG_PACKAGE_luci-i18n.*zh-cn=y" .config 2>/dev/null | sed 's/^/  /' || warn "未检测到已启用的中文包"

# 显示 files 目录结构
log "自定义 files 目录结构:"
find files -type f 2>/dev/null | sort | sed 's/^/  /' || warn "files 目录为空或不存在"

exit 0
