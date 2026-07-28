#!/bin/bash
# diy-part2.sh - E87N 专属定制 (最终修复版)

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

# --- 3. 重置 feeds 为最简配置 ---
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

# --- 6. 修复 mtk_hnat 驱动编译错误 ---
echo "### 6. 修复 mtk_hnat 驱动编译错误 ###"

# 修复 hnat.c
HNAT_C="${OPENWRT_DIR}/target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c"
if [ -f "$HNAT_C" ]; then
    if ! grep -q "FIXED_BY_SCRIPT" "$HNAT_C"; then
        echo "应用 hnat.c 补丁..."
        cat > "${HNAT_C}.pre" <<'EOF'
/* FIXED_BY_SCRIPT: 确保 u32 已定义并添加函数原型 */
#include <linux/types.h>

void mtk_set_pse_drop(u32 config);
void hnat_cache_clr(u32 ppe_id);

EOF
        cat "$HNAT_C" >> "${HNAT_C}.pre"
        mv "${HNAT_C}.pre" "$HNAT_C"
        echo "hnat.c 补丁已应用"
    fi
fi

# 修复 hnat_nf_hook.c
HNAT_NF_HOOK_C="${OPENWRT_DIR}/target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/hnat_nf_hook.c"
if [ -f "$HNAT_NF_HOOK_C" ]; then
    if ! grep -q "FIXED_BY_SCRIPT" "$HNAT_NF_HOOK_C"; then
        echo "应用 hnat_nf_hook.c 补丁..."
        
        # 添加 __maybe_unused 到 do_hnat_mape_w2l_fast
        sed -i 's/^static unsigned int do_hnat_mape_w2l_fast(/static __maybe_unused unsigned int do_hnat_mape_w2l_fast(/g' "$HNAT_NF_HOOK_C"
        
        # 其他函数添加 static
        sed -i 's/^void ppd_dev_setting(/static void ppd_dev_setting(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^void foe_clear_entry(/static void foe_clear_entry(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^unsigned int mape_add_ipv6_hdr(/static unsigned int mape_add_ipv6_hdr(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^unsigned int do_hnat_ext_to_ge(/static unsigned int do_hnat_ext_to_ge(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^unsigned int do_hnat_ext_to_ge2(/static unsigned int do_hnat_ext_to_ge2(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^unsigned int do_hnat_ge_to_ext(/static unsigned int do_hnat_ge_to_ext(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^void mtk_464xlat_pre_process(/static void mtk_464xlat_pre_process(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^struct foe_entry ppe_fill_L2_info(/static struct foe_entry ppe_fill_L2_info(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^struct foe_entry ppe_fill_info_blk(/static struct foe_entry ppe_fill_info_blk(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_fill_mac(/static int mtk_464xlat_fill_mac(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_get_hash(/static int mtk_464xlat_get_hash(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^void mtk_464xlat_fill_info1(/static void mtk_464xlat_fill_info1(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^void mtk_464xlat_fill_info2(/static void mtk_464xlat_fill_info2(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^void mtk_464xlat_fill_ipv4(/static void mtk_464xlat_fill_ipv4(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_fill_ipv6(/static int mtk_464xlat_fill_ipv6(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_fill_l2(/static int mtk_464xlat_fill_l2(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_fill_l3(/static int mtk_464xlat_fill_l3(/g' "$HNAT_NF_HOOK_C"
        sed -i 's/^int mtk_464xlat_post_process(/static int mtk_464xlat_post_process(/g' "$HNAT_NF_HOOK_C"
        
        sed -i '1i/* FIXED_BY_SCRIPT: 添加 static 和 __maybe_unused */' "$HNAT_NF_HOOK_C"
        echo "hnat_nf_hook.c 补丁已应用"
    else
        echo "hnat_nf_hook.c 补丁已存在"
    fi
else
    echo "警告: hnat_nf_hook.c 文件不存在"
fi

# --- 7. 安全设置目标配置 ---
echo "### 7. 设置目标配置 ###"

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

# --- 8. 复制 E87N DTS 文件 ---
echo "### 8. 复制 E87N DTS 文件 ###"
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

# --- 9. 验证 .config 文件 ---
echo "### 9. 验证配置 ###"
if [ -f ".config" ]; then
    echo ".config 文件大小: $(wc -c < .config) 字节"
    grep -E "CONFIG_TARGET_mediatek|CONFIG_MTK_WIFI" .config | grep -v "^#" || echo "无相关配置"
else
    echo "错误: .config 文件不存在!"
    exit 1
fi

echo "### diy-part2.sh 执行完成 ###"
