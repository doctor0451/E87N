#!/bin/bash
# diy-part2.sh - E87N 专属定制 (语法修复版)

OPENWRT_DIR="${GITHUB_WORKSPACE}/openwrt"
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: openwrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR" || exit 1

# --- 1. 删除所有 WiFi 相关包 ---
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

# --- 2. 删除有问题的 feeds 包 ---
echo "### 2. 删除有问题的 feeds 包 ###"
PROBLEM_PACKAGES=(
    "package/feeds/helloworld/luci-app-ssr-plus"
    "package/feeds/packages/nfs-kernel-server"
    "package/feeds/packages/onionshare-cli"
    "package/feeds/luci/luci-app-mjpg-streamer"
    "package/feeds/packages/net/freeradius3"
    "package/feeds/packages/net/nftables"
)

for pkg in "${PROBLEM_PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "删除: $pkg"
        rm -rf "$pkg"
    fi
done

# --- 3. 重置 feeds 配置 ---
echo "### 3. 重置 feeds 配置 ###"
cat > feeds.conf.default << 'EOF'
# 最简 feeds - 只使用官方核心源
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
EOF

# --- 4. 更新并安装 feeds ---
echo "### 4. 更新并安装 feeds ###"
./scripts/feeds update -a
./scripts/feeds install -a

# --- 5. 二次清理问题包 ---
echo "### 5. 二次清理问题包 ###"
for pkg in "${PROBLEM_PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "二次删除: $pkg"
        rm -rf "$pkg"
    fi
done

# --- 6. 在 mtk_hnat Makefile 中禁用警告 ---
echo "### 6. 在 mtk_hnat Makefile 中禁用警告 ###"

HNAT_MAKEFILE=""
for path in \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/Makefile" \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mtk_hnat/Makefile" \
    ; do
    if [ -f "${OPENWRT_DIR}/${path}" ]; then
        HNAT_MAKEFILE="${OPENWRT_DIR}/${path}"
        break
    fi
done

if [ -z "$HNAT_MAKEFILE" ]; then
    HNAT_MAKEFILE=$(find "${OPENWRT_DIR}/target/linux" -path "*/mtk_hnat/Makefile" 2>/dev/null | head -1)
fi

if [ -f "$HNAT_MAKEFILE" ]; then
    if ! grep -q "Wno-missing-prototypes" "$HNAT_MAKEFILE"; then
        echo "修改 Makefile: $HNAT_MAKEFILE"
        echo -e "\n# 禁用驱动中的警告（这些警告被 -Werror 视为错误）" >> "$HNAT_MAKEFILE"
        echo "ccflags-y += -Wno-missing-prototypes -Wno-unused-function" >> "$HNAT_MAKEFILE"
        echo "Makefile 已修改"
    else
        echo "Makefile 已包含编译标志"
    fi
else
    echo "警告: 找不到 mtk_hnat/Makefile"
fi

# --- 7. 修复 hnat.c 的 static 问题 ---
echo "### 7. 修复 hnat.c 的 static 问题 ###"
HNAT_C=""
for path in \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c" \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mtk_hnat/hnat.c" \
    ; do
    if [ -f "${OPENWRT_DIR}/${path}" ]; then
        HNAT_C="${OPENWRT_DIR}/${path}"
        break
    fi
done

if [ -z "$HNAT_C" ]; then
    HNAT_C=$(find "${OPENWRT_DIR}/target/linux" -name "hnat.c" -path "*/mtk_hnat/*" 2>/dev/null | head -1)
fi

if [ -f "$HNAT_C" ]; then
    if ! grep -q "FIXED_BY_SCRIPT" "$HNAT_C"; then
        echo "修复 hnat.c: $HNAT_C"
        
        # 在文件开头添加头文件和 static 声明
        cat > "${HNAT_C}.pre" <<'EOF'
/* FIXED_BY_SCRIPT: 确保 u32 已定义，并将函数标记为 static */
#include <linux/types.h>

/* 声明为 static，避免 -Wmissing-declarations */
static void mtk_set_pse_drop(u32 config);
static void hnat_cache_clr(u32 ppe_id);

EOF
        cat "$HNAT_C" >> "${HNAT_C}.pre"
        mv "${HNAT_C}.pre" "$HNAT_C"
        
        # 修复语法错误：使用 | 作为 sed 分隔符，避免与括号冲突
        sed -i 's|^void mtk_set_pse_drop(|static void mtk_set_pse_drop(|g' "$HNAT_C"
        sed -i 's|^void hnat_cache_clr(|static void hnat_cache_clr(|g' "$HNAT_C"
        
        echo "hnat.c 已修复"
    else
        echo "hnat.c 已包含修复"
    fi
else
    echo "警告: 找不到 hnat.c"
fi

# --- 8. 设置目标配置 ---
echo "### 8. 设置目标配置 ###"

make defconfig

if [ -x "./scripts/config" ] && [ ! -d "./scripts/config" ]; then
    echo "使用 scripts/config 设置构建选项"
    ./scripts/config --set-val CONFIG_TARGET_mediatek y
    ./scripts/config --set-val CONFIG_TARGET_mediatek_filogic y
    ./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

    ./scripts/config --disable CONFIG_MTK_WIFI7_SUPPORT
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt7992-firmware
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi7
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_hwifi
    ./scripts/config --disable CONFIG_PACKAGE_kmod-mt_wifi_osal
    ./scripts/config --disable CONFIG_PACKAGE_kmod-warp
    ./scripts/config --disable CONFIG_PACKAGE_kmod-wifi-profile
    ./scripts/config --disable CONFIG_PACKAGE_iw
    ./scripts/config --disable CONFIG_PACKAGE_iwinfo
    ./scripts/config --disable CONFIG_PACKAGE_hostapd-common
    ./scripts/config --disable CONFIG_PACKAGE_wpad-basic

    ./scripts/config --enable CONFIG_PACKAGE_kmod-pwm
    ./scripts/config --enable CONFIG_PACKAGE_kmod-thermal
    ./scripts/config --enable CONFIG_PACKAGE_kmod-spi-mediatek
else
    echo "scripts/config 不可执行，使用 .config 片段追加"
    cat >> .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n=y

CONFIG_MTK_WIFI7_SUPPORT=n
CONFIG_PACKAGE_kmod-mt7992-firmware=n
CONFIG_PACKAGE_kmod-mt_wifi7=n
CONFIG_PACKAGE_kmod-mt_hwifi=n
CONFIG_PACKAGE_kmod-mt_wifi_osal=n
CONFIG_PACKAGE_kmod-warp=n
CONFIG_PACKAGE_kmod-wifi-profile=n
CONFIG_PACKAGE_iw=n
CONFIG_PACKAGE_iwinfo=n
CONFIG_PACKAGE_hostapd-common=n
CONFIG_PACKAGE_wpad-basic=n

CONFIG_PACKAGE_kmod-pwm=y
CONFIG_PACKAGE_kmod-thermal=y
CONFIG_PACKAGE_kmod-spi-mediatek=y
EOF
fi

make defconfig

# --- 9. 复制 E87N DTS 文件 ---
echo "### 9. 复制 E87N DTS 文件 ###"
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
