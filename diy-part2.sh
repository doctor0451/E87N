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

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate



# diy-part2.sh EdgePI E87N MT7987A 无WiFi机型适配
# 基于 padavanonly mt798x 6.6 分支

echo "==================== Start DIY Part2 ===================="

# 1. 基础系统信息修改
sed -i 's/ImmortalWrt/EdgePI-E87N/g' package/base-files/files/bin/config_generate
sed -i 's/192.168.6.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i '/option hostname/s/immortalwrt/EdgePI-E87N/' package/base-files/files/bin/config_generate

# 2. 彻底禁用MTK内置WiFi驱动（本机无WiFi硬件）
# 删除WiFi相关内核配置、关闭WiFi7驱动、移除无线包
sed -i 's/CONFIG_PACKAGE_mt_wifi7=y/# CONFIG_PACKAGE_mt_wifi7 is not set/' .config
sed -i 's/CONFIG_PACKAGE_mt_hwifi=y/# CONFIG_PACKAGE_mt_hwifi is not set/' .config
sed -i 's/CONFIG_PACKAGE_wireless-regdb=y/# CONFIG_PACKAGE_wireless-regdb is not set/' .config
sed -i '/CONFIG_WLAN/d' target/linux/mediatek/filogic/config-6.6

# 3. 开启NVME、PCIe、eMMC大容量存储支持（双NVME插槽核心）
sed -i 's/# CONFIG_NVME_CORE=y/CONFIG_NVME_CORE=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_NVME_MT7622=y/CONFIG_NVME_MT7622=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_PCIE_MEDIATEK=y/CONFIG_PCIE_MEDIATEK=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_BLK_DEV_NVME=y/CONFIG_BLK_DEV_NVME=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_EFI_PARTITION=y/CONFIG_EFI_PARTITION=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_F2FS_FS=y/CONFIG_F2FS_FS=y/' target/linux/mediatek/filogic/config-6.6
sed -i 's/# CONFIG_F2FS_FS_SECURITY=y/CONFIG_F2FS_FS_SECURITY=y/' target/linux/mediatek/filogic/config-6.6

# 4. 开启8G eMMC大容量分区支持，关闭小容量闪存限制
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/CONFIG_TARGET_ROOTFS_PARTSIZE=6144/' .config

# 5. 硬件加速 HNAT/WED（MT7987A 有线转发加速）
sed -i 's/# CONFIG_MTK_HNAT=y/CONFIG_MTK_HNAT=y/' .config
sed -i 's/# CONFIG_MTK_WED=y/CONFIG_MTK_WED=y/' .config

# 6. 预装常用插件（无无线相关插件，侧重NAS/软路由/存储）
# 网络基础
sed -i 's/# CONFIG_PACKAGE_luci-app-firewall=y/CONFIG_PACKAGE_luci-app-firewall=y/' .config
sed -i 's/# CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=y/' .config
# 存储/NVME硬盘管理
sed -i 's/# CONFIG_PACKAGE_luci-app-diskman=y/CONFIG_PACKAGE_luci-app-diskman=y/' .config
sed -i 's/# CONFIG_PACKAGE_mountd=y/CONFIG_PACKAGE_mountd=y/' .config
sed -i 's/# CONFIG_PACKAGE_ntfs3-mount=y/CONFIG_PACKAGE_ntfs3-mount=y/' .config
sed -i 's/# CONFIG_PACKAGE_kmod-fs-f2fs=y/CONFIG_PACKAGE_kmod-fs-f2fs=y/' .config
# 家用代理/加速
sed -i 's/# CONFIG_PACKAGE_luci-app-passwall=y/CONFIG_PACKAGE_luci-app-passwall=y/' .config
sed -i 's/# CONFIG_PACKAGE_luci-app-adguardhome=y/CONFIG_PACKAGE_luci-app-adguardhome=y/' .config
# 系统监控
sed -i 's/# CONFIG_PACKAGE_luci-app-statistics=y/CONFIG_PACKAGE_luci-app-statistics=y/' .config
sed -i 's/# CONFIG_PACKAGE_htop=y/CONFIG_PACKAGE_htop=y/' .config
sed -i 's/# CONFIG_PACKAGE_iperf3=y/CONFIG_PACKAGE_iperf3=y/' .config
# 去除无用无线luci页面
sed -i 's/CONFIG_PACKAGE_luci-app-wireless=y/# CONFIG_PACKAGE_luci-app-wireless is not set/' .config

# 7. 重新生成defconfig校验配置
make defconfig

echo "==================== DIY Part2 Finished ===================="


