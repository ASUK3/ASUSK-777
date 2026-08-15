#!/bin/bash
#
# OpenWrt DIY script part 1 (更新 feeds 前执行)
# 功能：修改默认 IP、主机名、时区、NTP 服务器等基础配置
#

# 注意：不要使用 set -euo pipefail，避免 sed 未匹配时意外退出

# 定义日志函数（使用 function 关键字，兼容性更好）
function log() {
  echo -e "\033[1;32m[DIY-1]\033[0m $*"
}

function warn() {
  echo -e "\033[1;33m[DIY-1 警告]\033[0m $*"
}

function err() {
  echo -e "\033[1;31m[DIY-1 错误]\033[0m $*"
}

# -----------------------------------------------------------------------------
# 配置文件路径
# -----------------------------------------------------------------------------
CFG_GEN="package/base-files/files/bin/config_generate"

# -----------------------------------------------------------------------------
# 检查配置文件是否存在
# -----------------------------------------------------------------------------
if [[ ! -f "$CFG_GEN" ]]; then
  warn "未找到配置文件: $CFG_GEN"
  warn "尝试查找其他可能的路径..."
  
  # 尝试查找 config_generate 的实际位置
  ALT_PATH=$(find . -name "config_generate" -type f 2>/dev/null | head -n 1)
  if [[ -n "$ALT_PATH" ]]; then
    log "找到替代路径: $ALT_PATH"
    CFG_GEN="$ALT_PATH"
  else
    err "无法找到 config_generate 文件，跳过基础配置修改"
    log "diy-part1 执行完毕（部分跳过）"
    exit 0
  fi
fi

log "正在修改配置文件: $CFG_GEN"

# -----------------------------------------------------------------------------
# 1. 修改默认 LAN IP 为 192.168.6.1
# -----------------------------------------------------------------------------
log ">>> 修改默认 LAN IP -> 192.168.6.1"

# 检查当前 IP 设置
CURRENT_IP=$(grep -oE 'ipaddr:-"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' "$CFG_GEN" | head -n 1 | cut -d'"' -f2)
if [[ -n "$CURRENT_IP" ]]; then
  log "当前默认 IP: $CURRENT_IP"
else
  warn "未检测到当前 IP 设置，尝试强制替换..."
fi

# 方式1：标准格式 ipaddr:-"xxx.xxx.xxx.xxx"
if grep -q 'ipaddr:-"[0-9]' "$CFG_GEN"; then
  sed -i -E 's/(ipaddr:-)"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"/\1"192.168.6.1"/g' "$CFG_GEN"
  log "✓ IP 已通过方式1修改"
else
  # 方式2：兼容其他格式
  warn "方式1未匹配，尝试方式2..."
  if grep -q "192\.168\.[0-9]*\.[0-9]*" "$CFG_GEN"; then
    sed -i -E 's/192\.168\.[0-9]+\.[0-9]+/192.168.6.1/g' "$CFG_GEN"
    log "✓ IP 已通过方式2修改"
  else
    warn "未找到可替换的 IP 地址格式"
  fi
fi

# 验证修改结果
NEW_IP=$(grep -oE 'ipaddr:-"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' "$CFG_GEN" | head -n 1 | cut -d'"' -f2)
[[ -n "$NEW_IP" ]] && log "修改后 IP: $NEW_IP"

# -----------------------------------------------------------------------------
# 2. 修改主机名为 ASUSWRT
# -----------------------------------------------------------------------------
log ">>> 修改主机名 -> ASUSWRT"

# 检查当前主机名设置
CURRENT_HOSTNAME=$(grep -oE "hostname='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
if [[ -n "$CURRENT_HOSTNAME" ]]; then
  log "当前主机名: $CURRENT_HOSTNAME"
fi

# 方式1：标准格式 hostname='xxx'
if grep -q "hostname='" "$CFG_GEN"; then
  sed -i -E "s/(hostname=)'[^']*'/\1'ASUSWRT'/g" "$CFG_GEN"
  log "✓ 主机名已通过方式1修改"
else
  # 方式2：双引号格式 hostname="xxx"
  warn "方式1未匹配，尝试方式2..."
  if grep -q 'hostname="' "$CFG_GEN"; then
    sed -i -E 's/(hostname=)"[^"]*"/\1"ASUSWRT"/g' "$CFG_GEN"
    log "✓ 主机名已通过方式2修改"
  else
    warn "未找到可替换的主机名格式"
  fi
fi

# 验证修改结果
NEW_HOSTNAME=$(grep -oE "hostname='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
[[ -n "$NEW_HOSTNAME" ]] && log "修改后主机名: $NEW_HOSTNAME"

# -----------------------------------------------------------------------------
# 3. 修改时区为 CST-8 / Asia/Shanghai
# -----------------------------------------------------------------------------
log ">>> 修改时区 -> CST-8 / Asia/Shanghai"

# 检查当前时区
CURRENT_TZ=$(grep -oE "timezone='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
CURRENT_ZONE=$(grep -oE "zonename='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
log "当前时区: timezone=$CURRENT_TZ, zonename=$CURRENT_ZONE"

# 修改 timezone
if grep -q "timezone='UTC'" "$CFG_GEN"; then
  sed -i "s/timezone='UTC'/timezone='CST-8'/g" "$CFG_GEN"
  log "✓ timezone 已修改"
elif grep -q "timezone='" "$CFG_GEN"; then
  sed -i -E "s/timezone='[^']*'/timezone='CST-8'/g" "$CFG_GEN"
  log "✓ timezone 已强制修改"
else
  warn "未找到 timezone 设置"
fi

# 修改 zonename（使用 | 作为分隔符，避免转义地狱）
if grep -q "zonename='UTC'" "$CFG_GEN"; then
  sed -i "s|zonename='UTC'|zonename='Asia/Shanghai'|g" "$CFG_GEN"
  log "✓ zonename 已修改"
elif grep -q "zonename='" "$CFG_GEN"; then
  sed -i -E "s|zonename='[^']*'|zonename='Asia/Shanghai'|g" "$CFG_GEN"
  log "✓ zonename 已强制修改"
else
  warn "未找到 zonename 设置"
fi

# 验证修改结果
NEW_TZ=$(grep -oE "timezone='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
NEW_ZONE=$(grep -oE "zonename='[^']*'" "$CFG_GEN" | head -n 1 | cut -d"'" -f2)
log "修改后时区: timezone=$NEW_TZ, zonename=$NEW_ZONE"

# -----------------------------------------------------------------------------
# 4. 修改 NTP 服务器为国内源
# -----------------------------------------------------------------------------
log ">>> 修改 NTP 服务器 -> 国内源"

# 国内 NTP 服务器列表
NTP_SERVERS="ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org"

# 显示当前 NTP 配置
log "当前 NTP 配置:"
grep -n "server=" "$CFG_GEN" 2>/dev/null || warn "未找到 server= 格式的 NTP 配置"

# 方式1：替换 openwrt.pool.ntp.org 系列
if grep -q "0.openwrt.pool.ntp.org" "$CFG_GEN"; then
  sed -i "s/server='0\.openwrt\.pool\.ntp\.org 1\.openwrt\.pool\.ntp\.org 2\.openwrt\.pool\.ntp\.org 3\.openwrt\.pool\.ntp\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" "$CFG_GEN"
  log "✓ NTP 已通过方式1修改（openwrt.pool 系列）"
fi

# 方式2：替换标准 pool.ntp.org 系列
if grep -q "0.pool.ntp.org" "$CFG_GEN"; then
  sed -i "s/server='0\.pool\.ntp\.org 1\.pool\.ntp\.org 2\.pool\.ntp\.org 3\.pool\.ntp\.org'/server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'/g" "$CFG_GEN"
  log "✓ NTP 已通过方式2修改（标准 pool 系列）"
fi

# 方式3：通用替换所有 pool.ntp.org 为 cn.pool.ntp.org
if grep -q "pool.ntp.org" "$CFG_GEN"; then
  sed -i "s/pool\.ntp\.org/cn\.pool\.ntp\.org/g" "$CFG_GEN"
  log "✓ NTP 已通过方式3修改（通用替换 pool.ntp.org -> cn.pool.ntp.org）"
fi

# 方式4：如果还是默认配置，尝试强制替换
if ! grep -q "ntp.aliyun.com" "$CFG_GEN"; then
  warn "未成功替换为阿里云 NTP，尝试强制替换..."
  if grep -qE "server=.*ntp.*\.org" "$CFG_GEN"; then
    sed -i -E "s|server='[^']*ntp[^']*'|server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'|g" "$CFG_GEN"
    log "✓ NTP 已通过方式4强制修改"
  fi
fi

# 显示修改后的 NTP 配置
log "修改后 NTP 配置:"
grep -n "server=" "$CFG_GEN" 2>/dev/null || warn "仍未找到 server= 格式的 NTP 配置"

# -----------------------------------------------------------------------------
# 完成
# -----------------------------------------------------------------------------
log "========================================"
log "diy-part1 执行完毕"
log "========================================"

# 显示 config_generate 的关键修改部分
log "配置文件关键内容预览:"
head -n 80 "$CFG_GEN" || true

exit 0
