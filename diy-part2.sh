#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# ============================================================
# 1. 修改默认 IP 地址（避免与光猫冲突）
# ============================================================
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# ============================================================
# 2. 修改默认主机名
# ============================================================
sed -i 's/OpenWrt/EdgePI-E87N/g' package/base-files/files/bin/config_generate

# ============================================================
# 3. 添加额外的软件包源（如有需要）
# ============================================================
# 示例：添加 helloworld 源（科学上网）
# echo 'src-git helloworld https://github.com/fw876/helloworld' >> feeds.conf.default

# 示例：添加 passwall 源
# echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >> feeds.conf.default

# ============================================================
# 4. 删除 WiFi 相关配置（E87N 无板载 WiFi）
# ============================================================
# 删除默认的 WiFi 配置文件，避免启动时尝试初始化不存在的硬件
rm -f package/base-files/files/etc/config/wireless 2>/dev/null

# ============================================================
# 5. 确保 NVMe 相关内核模块被选中（.config 已包含，此处仅作保险）
# ============================================================
# 如果 .config 中未启用，可在此通过 sed 追加
# 但推荐直接在 .config 中配置

echo "DIY part 2 completed."
