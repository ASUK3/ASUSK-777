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

#添加计划任务
echo '0 2 * * * rm -rf /var/log/*' >> files/etc/crontabs/root
echo '*/30 * * * * /etc/init.d/dnsmasq restart' >> files/etc/crontabs/root
