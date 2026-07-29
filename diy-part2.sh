#!/bin/bash
# diy-part2.sh - E87N 专属定制 (最终语法修复版)

set -e  # 遇到错误立即退出

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
        
        cat > "${HNAT_C}.pre" <<'EOF'
/* FIXED_BY_SCRIPT: 确保 u32 已定义，并将函数标记为 static */
#include <linux/types.h>

static void mtk_set_pse_drop(u32 config);
static void hnat_cache_clr(u32 ppe_id);

EOF
        cat "$HNAT_C" >> "${HNAT_C}.pre"
        mv "${HNAT_C}.pre" "$HNAT_C"
        
        # 修复：移除多余的 ) 并转义 ( 
        sed -i 's|^void mtk_set_pse_drop\(|static void mtk_set_pse_drop(|g' "$HNAT_C"
        sed -i 's|^void hnat_cache_clr\(|static void hnat_cache_clr(|g' "$HNAT_C"
        
        echo "hnat.c 已修复"
    else
        echo "hnat.c 已包含修复"
    fi
else
    echo "警告: 找不到 hnat.c"
fi

# --- 8. 修复 hnat_nf_hook.c 的 static 问题 ---
echo "### 8. 修复 hnat_nf_hook.c 的 static 问题 ###"
HNAT_NF_HOOK_C=""
for path in \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/hnat_nf_hook.c" \
    "target/linux/mediatek/files-6.12/drivers/net/ethernet/mtk_hnat/hnat_nf_hook.c" \
    ; do
    if [ -f "${OPENWRT_DIR}/${path}" ]; then
        HNAT_NF_HOOK_C="${OPENWRT_DIR}/${path}"
        break
    fi
done

if [ -z "$HNAT_NF_HOOK_C" ]; then
    HNAT_NF_HOOK_C=$(find "${OPENWRT_DIR}/target/linux" -name "hnat_nf_hook.c" -path "*/mtk_hnat/*" 2>/dev/null | head -1)
fi

if [ -f "$HNAT_NF_HOOK_C" ]; then
    if ! grep -q "FIXED_BY_SCRIPT" "$HNAT_NF_HOOK_C"; then
        echo "修复 hnat_nf_hook.c: $HNAT_NF_HOOK_C"
        
        sed -i '1i/* FIXED_BY_SCRIPT: 将内部函数标记为 static */' "$HNAT_NF_HOOK_C"
        
        # 使用转义的 ( 避免 shell 解析问题
        sed -i 's|^void ppd_dev_setting\(|static void ppd_dev_setting(|g' "$HNAT_NF_HOOK_C"
        sed -i 's|^void foe_clear_entry\(|static void foe_clear_entry(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^unsigned int mape_add_ipv6_hdr\(|static unsigned int mape_add_ipv6_hdr(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^unsigned int do_hnat_ext_to_ge\(|static unsigned int do_hnat_ext_to_ge(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^unsigned int do_hnat_ext_to_ge2\(|static unsigned int do_hnat_ext_to_ge2(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^unsigned int do_hnat_ge_to_ext\(|static unsigned int do_hnat_ge_to_ext(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^unsigned int do_hnat_mape_w2l_fast\(|static unsigned int do_hnat_mape_w2l_fast(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^void mtk_464xlat_pre_process\(|static void mtk_464xlat_pre_process(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^struct foe_entry ppe_fill_L2_info\(|static struct foe_entry ppe_fill_L2_info(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^struct foe_entry ppe_fill_info_blk\(|static struct foe_entry ppe_fill_info_blk(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_fill_mac\(|static int mtk_464xlat_fill_mac(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_get_hash\(|static int mtk_464xlat_get_hash(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^void mtk_464xlat_fill_info1\(|static void mtk_464xlat_fill_info1(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^void mtk_464xlat_fill_info2\(|static void mtk_464xlat_fill_info2(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^void mtk_464xlat_fill_ipv4\(|static void mtk_464xlat_fill_ipv4(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_fill_ipv6\(|static int mtk_464xlat_fill_ipv6(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_fill_l2\(|static int mtk_464xlat_fill_l2(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_fill_l3\(|static int mtk_464xlat_fill_l3(|g' "$HNAT_NF_HOOK_C")
        sed -i 's|^int mtk_464xlat_post_process\(|static int mtk_464xlat_post_process(|g' "$HNAT_NF_HOOK_C")
        
        echo "hnat_nf_hook.c 已修复"
    else
        echo "hnat_nf_hook.c 已包含修复"
    fi
else
    echo "警告: 找不到 hnat_nf_hook.c"
fi

# --- 9. 设置目标配置 ---
echo "### 9. 设置目标配置 ###"

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

# --- 10. 复制 E87N DTS 文件 ---
echo "### 10. 复制 E87N DTS 文件 ###"
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
