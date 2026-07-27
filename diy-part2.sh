#!/bin/bash
# diy-part2.sh - E87N 专属定制

# 使用绝对路径
OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 物理删除所有 WiFi 相关包目录 ---
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
    if [ -d "${pkg}.disabled" ]; then
        echo "删除: ${pkg}.disabled"
        rm -rf "${pkg}.disabled"
    fi
done

# --- 2. 替换 feeds.conf.default 为最小配置 ---
echo "### 替换 feeds.conf.default 为最小配置 ###"
cat > feeds.conf.default << 'EOF'
# 最小 feeds 配置 - 仅包含核心包
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
src-git telephony https://git.openwrt.org/feed/telephony.git
# 注释掉可能包含问题包的 feed
# src-git mtk https://github.com/Hiveton/mtk-feed.git
EOF

# --- 3. 重新更新 feeds ---
echo "### 重新更新 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 4. 清理可能存在的有问题的包 ---
echo "### 清理有问题的包 ###"
# 删除 onionshare-cli（如果有）
if [ -d "package/feeds/packages/onionshare-cli" ]; then
    echo "删除: package/feeds/packages/onionshare-cli"
    rm -rf package/feeds/packages/onionshare-cli
fi
# 删除 luci-app-mjpg-streamer（如果有）
if [ -d "package/feeds/luci/luci-app-mjpg-streamer" ]; then
    echo "删除: package/feeds/luci/luci-app-mjpg-streamer"
    rm -rf package/feeds/luci/luci-app-mjpg-streamer
fi

# --- 5. 执行 defconfig ---
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

# --- 6. 复制 E87N DTS 文件到源码目录 ---
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

# --- 7. 清理 Makefile 中的问题依赖（可选） ---
echo "### 清理问题依赖 ###"
# 如果有其他有问题的包，在这里添加

echo "### diy-part2.sh 执行完成 ###"
