#!/bin/bash
# diy-part2.sh - E87N 专属定制 (干净版本)

OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 完全重置 feeds 配置 ---
echo "### 1. 重置 feeds 配置为最简状态 ###"
cat > feeds.conf.default << 'EOF'
# 最简 feeds - 只使用官方核心源
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
EOF

# --- 2. 更新并安装 feeds ---
echo "### 2. 更新并安装 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 3. 暴力删除所有可能干扰的包 ---
echo "### 3. 删除干扰包 ###"
# 删除整个 feeds 目录中可能有问题的大类
rm -rf package/feeds/helloworld 2>/dev/null || true
rm -rf package/feeds/packages/nfs-kernel-server 2>/dev/null || true
rm -rf package/feeds/packages/onionshare-cli 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-mjpg-streamer 2>/dev/null || true
rm -rf package/feeds/luci/luci-app-ssr-plus 2>/dev/null || true

# --- 4. 删除所有 WiFi 驱动包 ---
echo "### 4. 删除 WiFi 驱动包 ###"
rm -rf package/mtk/drivers/mt_wifi7 2>/dev/null || true
rm -rf package/mtk/drivers/mt_hwifi 2>/dev/null || true
rm -rf package/mtk/drivers/mt_wifi_osal 2>/dev/null || true
rm -rf package/mtk/drivers/warp 2>/dev/null || true
rm -rf package/mtk/drivers/wifi-profile 2>/dev/null || true

# --- 5. 删除非 MTK 平台干扰 ---
echo "### 5. 删除非 MTK 平台 ###"
# 只删除明确有问题的 siflower
rm -rf target/linux/siflower 2>/dev/null || true

# --- 6. 生成一个最简的 .config（只编译 mediatek/filogic） ---
echo "### 6. 生成最简配置 ###"
# 使用默认配置，然后强制设置目标
make defconfig

# 使用 scripts/config 设置目标
./scripts/config --set-val CONFIG_TARGET_mediatek y
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic y
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

# 禁用所有 WiFi
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

# 再次执行 defconfig 应用更改
make defconfig

# --- 7. 复制 E87N DTS 文件 ---
echo "### 7. 复制 E87N DTS 文件 ###"
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

# --- 8. 验证关键目录 ---
echo "### 8. 验证关键目录 ###"
ls -la target/linux/mediatek/
ls -la target/linux/mediatek/dts/ 2>/dev/null || echo "dts目录为空"

echo "### diy-part2.sh 执行完成 ###"
