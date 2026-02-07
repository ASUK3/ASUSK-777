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

# ===== TCP / 网络 / 内存 调度优化（强制生效，sysctl.d）=====

mkdir -p files/etc/sysctl.d

cat > files/etc/sysctl.d/99-network-opt.conf << 'EOF'
############################################
# Queue / Congestion Control
############################################
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

############################################
# Connection / Backlog
############################################
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 2048

############################################
# Socket Buffer
############################################
net.core.rmem_default = 131072
net.core.wmem_default = 131072
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608

net.ipv4.tcp_rmem = 4096 131072 8388608
net.ipv4.tcp_wmem = 4096 131072 8388608

############################################
# TCP Behavior
############################################
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_limit_output_bytes = 131072
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_retries2 = 10
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_rto_min = 200
net.ipv4.tcp_ecn = 1

############################################
# Keepalive
############################################
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

############################################
# UDP
############################################
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_mem = 524288 1048576 2097152

############################################
# Busy Poll
############################################
net.core.busy_read = 50
net.core.busy_poll = 50

############################################
# Security / Redirects
############################################
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

############################################
# IPv6
############################################
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.default.autoconf = 0
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.conf.default.use_tempaddr = 0

net.ipv6.neigh.default.gc_thresh1 = 1024
net.ipv6.neigh.default.gc_thresh2 = 4096
net.ipv6.neigh.default.gc_thresh3 = 8192

############################################
# Conntrack
############################################
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 300
EOF
