#!/bin/bash
# diy-part2.sh - E87N 专属定制 (保留 Higowrt 特性)

OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 暴力删除所有干扰包，但保留 Higowrt 核心驱动 ---
echo "### 1. 删除干扰包，保留核心驱动 ###"

# 只删除有问题的 feeds 包
rm -rf package/feeds/helloworld 2>/dev/null || true
rm -rf package/feeds/packages/nfs-kernel-server 2>/dev/null || true
rm -rf package/feeds/packages/onionshare-cli 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-mjpg-streamer 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-ssr-plus 2>/dev/null || true

# 重要：不要删除 package/mtk/drivers/ 下的驱动！
# 这些驱动包含了风扇、屏幕等硬件的支持

# --- 2. 重置 feeds 为最简配置 ---
echo "### 2. 重置 feeds 配置 ###"
cat > feeds.conf.default << 'EOF'
# 最简 feeds - 只使用官方核心源 + Higowrt 驱动源
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
# 保留 Higowrt 的驱动源（如果有）
# src-git mtk https://github.com/Hiveton/mtk-feed.git
EOF

# --- 3. 重新更新并安装 feeds ---
echo "### 3. 重新更新并安装 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 4. 二次清理问题包 ---
echo "### 4. 二次清理问题包 ###"
rm -rf package/feeds/helloworld 2>/dev/null || true
rm -rf package/feeds/packages/nfs-kernel-server 2>/dev/null || true
rm -rf package/feeds/packages/onionshare-cli 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-mjpg-streamer 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-ssr-plus 2>/dev/null || true

# --- 5. 设置目标并生成配置 ---
echo "### 5. 生成目标配置 ###"

# 强制设置目标为 E87N
./scripts/config --set-val CONFIG_TARGET_mediatek y
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic y
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

# 禁用 WiFi 但保留其他驱动
./scripts/config --disable CONFIG_MTK_WIFI7_SUPPORT
./scripts/config --disable CONFIG_PACKAGE_kmod-mt7992-firmware
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi7
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_hwifi
./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi_osal
./scripts/config --disable CONFIG_PACKAGE_kmod-warp
./scripts/config --disable CONFIG_PACKAGE_wifi-profile

# 确保风扇和屏幕相关驱动被启用
./scripts/config --enable CONFIG_PACKAGE_kmod-pwm
./scripts/config --enable CONFIG_PACKAGE_kmod-thermal
./scripts/config --enable CONFIG_PACKAGE_kmod-spi-mediatek

make defconfig

# --- 6. 复制 E87N DTS 文件 ---
echo "### 6. 复制 E87N DTS 文件 ###"
DTS_SRC="${GITHUB_WORKSPACE}/DTS"
DTS_DST="${OPENWRT_DIR}/target/linux/mediatek/dts"

if [ -d "$DTS_SRC" ]; then
    mkdir -p "$DTS_DST"
    cp -v "$DTS_SRC"/*.dts "$DTS_DST/" 2>/dev/null || true
    cp -v "$DTS_SRC"/*.dtsi "$DTS_DST/" 2>/dev/null || true
    echo "DTS文件复制完成"
else
    echo "警告: DTS目录不存在: $DTS_SRC"
fi

echo "### diy-part2.sh 执行完成 ###"
