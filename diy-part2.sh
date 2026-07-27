#!/bin/bash
# diy-part2.sh - E87N 专属定制

# 重要：脚本在 $GITHUB_WORKSPACE 目录下执行
# 但 openwrt 源码目录在 /workdir/openwrt
# 我们需要使用绝对路径或正确切换

# 使用环境变量或固定路径
OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 强化禁用Wi-Fi相关配置 ---
echo "### 强制禁用Wi-Fi模块 ###"
./scripts/config --disable CONFIG_MTK_WIFI7_SUPPORT
./scripts/config --disable CONFIG_PACKAGE_kmod-mt7992-firmware
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi7
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_hwifi
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi_osal
./scripts/config --disable CONFIG_PACKAGE_kmod-warp
./scripts/config --disable CONFIG_PACKAGE_wifi-profile
./scripts/config --disable CONFIG_PACKAGE_iw
./scripts/config --disable CONFIG_PACKAGE_iwinfo
./scripts/config --disable CONFIG_PACKAGE_hostapd-common

# --- 2. 确保E87N设备被正确选择 ---
echo "### 设置E87N为目标设备 ###"
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

# --- 3. 清理可能因WiFi驱动产生的依赖冲突 ---
echo "### 清理WiFi驱动残留 ###"
make package/mtk/drivers/mt_wifi7/clean -j1 || true
make package/mtk/drivers/mt_hwifi/clean -j1 || true

# --- 4. 复制E87N DTS文件到源码目录 ---
echo "### 复制E87N DTS文件 ###"
DTS_SRC="${GITHUB_WORKSPACE}/DTS"
DTS_DST="${OPENWRT_DIR}/target/linux/mediatek/dts"

if [ -d "$DTS_SRC" ]; then
    cp -v "$DTS_SRC"/*.dts "$DTS_DST/" 2>/dev/null || true
    cp -v "$DTS_SRC"/*.dtsi "$DTS_DST/" 2>/dev/null || true
    echo "DTS文件复制完成"
else
    echo "警告: DTS目录不存在: $DTS_SRC"
fi

echo "### diy-part2.sh 执行完成 ###"
