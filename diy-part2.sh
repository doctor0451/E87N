#!/bin/bash
# diy-part2.sh - E87N 专属定制

# 使用绝对路径
OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 物理删除所有 WiFi 相关包目录（不是移动，是删除） ---
echo "### 删除所有 WiFi 相关包 ###"
WIFI_PACKAGES=(
    "package/mtk/drivers/mt_wifi7"
    "package/mtk/drivers/mt_hwifi"
    "package/mtk/drivers/mt_wifi_osal"
    "package/mtk/drivers/warp"
    "package/mtk/drivers/wifi-profile"
)

for pkg in "${WIFI_PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "删除: $pkg"
        rm -rf "$pkg"
    fi
    # 也删除可能存在的 .disabled 版本
    if [ -d "${pkg}.disabled" ]; then
        echo "删除: ${pkg}.disabled"
        rm -rf "${pkg}.disabled"
    fi
done

# --- 2. 清理 feeds 配置中的 WiFi 相关条目 ---
echo "### 清理 feeds 配置 ###"
if [ -f "feeds.conf.default" ]; then
    # 备份原文件
    cp feeds.conf.default feeds.conf.default.bak
    # 注释掉 mtk 相关的 feed 行
    sed -i '/mtk/d' feeds.conf.default
    # 也注释掉可能包含 wifi 的 feed
    sed -i '/wifi/d' feeds.conf.default
    echo "feeds.conf.default 已清理"
fi

# --- 3. 重新更新 feeds ---
echo "### 重新更新 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 4. 执行 defconfig ---
echo "### 执行 defconfig ###"
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
./scripts/config --disable CONFIG_PACKAGE_wpad-basic

# 设置目标设备
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

make defconfig

# --- 5. 复制 E87N DTS 文件到源码目录 ---
echo "### 复制 E87N DTS 文件 ###"
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
