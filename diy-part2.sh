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
echo "### 1. 删除所有 WiFi 相关包 ###"
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

# --- 2. 创建最小 feeds.conf.default ---
echo "### 2. 创建最小 feeds 配置 ###"
cat > feeds.conf.default << 'EOF'
# 最小 feeds 配置 - 仅包含核心包
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
EOF

# --- 3. 更新 feeds（这里会下载包） ---
echo "### 3. 更新 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 4. 再次删除有问题的包（feeds 更新后可能重新出现） ---
echo "### 4. 删除有问题的 feeds 包 ###"
PROBLEM_PACKAGES=(
    "package/feeds/helloworld/luci-app-ssr-plus"
    "package/feeds/packages/nfs-kernel-server"
    "package/feeds/packages/onionshare-cli"
    "package/feeds/luci/luci-app-mjpg-streamer"
    # 也删除可能存在的变体
    "package/feeds/packages/nfs-kernel-server"
)

for pkg in "${PROBLEM_PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "删除: $pkg"
        rm -rf "$pkg"
    fi
done

# --- 5. 删除 siflower 平台 ---
echo "### 5. 删除 siflower 平台 ###"
if [ -d "target/linux/siflower" ]; then
    echo "删除: target/linux/siflower"
    rm -rf target/linux/siflower
fi

# --- 6. 执行 defconfig ---
echo "### 6. 执行 defconfig ###"
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

# --- 7. 复制 E87N DTS 文件到源码目录 ---
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

# --- 8. 验证 target/linux/mediatek 目录 ---
echo "### 8. 验证目录结构 ###"
if [ -d "target/linux/mediatek" ]; then
    echo "target/linux/mediatek 存在"
    ls -la target/linux/mediatek/ | head -20
else
    echo "错误: target/linux/mediatek 不存在!"
    exit 1
fi

echo "### diy-part2.sh 执行完成 ###"
