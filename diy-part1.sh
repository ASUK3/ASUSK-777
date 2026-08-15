# 备选方案：通过 uci-defaults 脚本在首次启动时修改配置
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-settings << 'EOF'
#!/bin/sh
# 修改 LAN IP
uci set network.lan.ipaddr='192.168.6.1'
uci commit network

# 修改主机名
uci set system.@system[0].hostname='ASUSWRT'
uci commit system

# 修改时区
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system

# 修改 NTP
uci set system.ntp.server='ntp.aliyun.com time1.cloud.tencent.com ntp.tuna.tsinghua.edu.cn ntp.ntsc.ac.cn cn.pool.ntp.org'
uci commit system

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings
log "✓ 已通过 uci-defaults 方式设置自定义配置"
