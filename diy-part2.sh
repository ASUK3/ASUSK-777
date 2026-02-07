#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX
#
# OpenWrt DIY script part 2 (After Update feeds)
#
sed -i 's/luci-theme-bootstrap/luci-theme-argonv3/g' feeds/luci/collections/luci/Makefile || true

set -euo pipefail

# ===== TCP / 网络 / 内存 调度优化（强制生效：sysctl.d）=====
# - 启动时由 /etc/sysctl.d/*.conf 自动加载
# - 单文件统一管理，避免重复/顺序问题

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
# Socket Buffer (memory-rich, low latency)
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
# UDP (low-latency baseline)
############################################
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384

############################################
# Busy Poll (lowest latency, CPU trade-off)
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
