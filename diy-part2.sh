#!/bin/bash
# diy-part2.sh - E87N 专属定制

# 使用绝对路径
OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 先移除有问题的 WiFi 包配置（在 olddefconfig 之前） ---
echo "### 移除有问题的 WiFi 包配置 ###"
# 移除 mt_wifi7 包的配置目录（暂时移动）
if [ -d "package/mtk/drivers/mt_wifi7" ]; then
    echo "移动 mt_wifi7 包以避免配置错误"
    mv package/mtk/drivers/mt_wifi7 package/mtk/drivers/mt_wifi7.disabled
fi

# 移除 warp 包（依赖 kmod-hw_nat，也不存在）
if [ -d "package/mtk/drivers/warp" ]; then
    echo "移动 warp 包以避免依赖错误"
    mv package/mtk/drivers/warp package/mtk/drivers/warp.disabled
fi

# 移除 mt_hwifi 包
if [ -d "package/mtk/drivers/mt_hwifi" ]; then
    echo "移动 mt_hwifi 包"
    mv package/mtk/drivers/mt_hwifi package/mtk/drivers/mt_hwifi.disabled
fi

# 移除 mt_wifi_osal 包
if [ -d "package/mtk/drivers/mt_wifi_osal" ]; then
    echo "移动 mt_wifi_osal 包"
    mv package/mtk/drivers/mt_wifi_osal package/mtk/drivers/mt_wifi_osal.disabled
fi

# 移除 wifi-profile 包
if [ -d "package/mtk/drivers/wifi-profile" ]; then
    echo "移动 wifi-profile 包"
    mv package/mtk/drivers/wifi-profile package/mtk/drivers/wifi-profile.disabled
fi

# --- 2. 修改 feeds 配置，移除可能导致问题的包 ---
echo "### 处理 feeds 配置 ###"
# 检查 feeds.conf.default，注释掉可能引入问题包的 feed
if [ -f "feeds.conf.default" ]; then
    # 备份原文件
    cp feeds.conf.default feeds.conf.default.bak
    # 注释掉 mtk 相关的 feed（如果有）
    sed -i 's/^src-git mtk/#src-git mtk/g' feeds.conf.default 2>/dev/null || true
fi

# --- 3. 更新 feeds（重新处理） ---
echo "### 重新更新 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 4. 使用正确的 .config 并执行 defconfig ---
echo "### 执行 defconfig ###"
if [ -f ".config" ]; then
    # 确保禁用所有 WiFi 选项
    ./scripts/config --disable CONFIG_MTK_WIFI7_SUPPORT
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt7992-firmware
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi7
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_hwifi
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi_osal
    ./scripts/config --disable CONFIG_PACKAGE_kmod-warp
    ./scripts/config --disable CONFIG_PACKAGE_wifi-profile
    
    # 设置目标设备
    ./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y
fi

# 执行 defconfig
make defconfig

# --- 5. 复制 E87N DTS 文件 ---
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
