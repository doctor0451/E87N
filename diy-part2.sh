#!/bin/bash
# diy-part2.sh - E87N 专属定制 (修复 nftables-nojson 递归依赖)

set -e

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

# --- 2. 删除有问题的 feeds 包（含 Kconfig 递归依赖） ---
echo "### 2. 删除有问题的 feeds 包 ###"
PROBLEM_PACKAGES=(
    "package/feeds/helloworld/luci-app-ssr-plus"
    "package/feeds/packages/nfs-kernel-server"
    "package/feeds/packages/onionshare-cli"
    "package/feeds/luci/luci-app-mjpg-streamer"
    "package/feeds/packages/net/freeradius3"
    "package/feeds/packages/net/nftables"
    "package/feeds/packages/lang/lua-eco"
    "package/feeds/packages/net/nftables-nojson"
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

# --- 6. 禁用 nftables-nojson 递归依赖（关键修复） ---
echo "### 6. 禁用 nftables-nojson 递归依赖 ###"

# 方法1：使用 scripts/config（如果可用）
if [ -x "./scripts/config" ] && [ ! -d "./scripts/config" ]; then
    echo "使用 scripts/config 禁用 PACKAGE_nftables-nojson"
    ./scripts/config --disable PACKAGE_nftables-nojson || true
else
    echo "scripts/config 不可用，直接修改 .config"
    # 从 .config 中删除相关行
    sed -i '/nftables-nojson/d' .config 2>/dev/null || true
    # 确保被禁用
    if ! grep -q '^# CONFIG_PACKAGE_nftables-nojson is not set' .config; then
        echo '# CONFIG_PACKAGE_nftables-nojson is not set' >> .config
    fi
fi

# 额外：在 tmp/.config-package.in 中查找并注释掉递归依赖
# 这是一个更彻底的修复
if [ -f "tmp/.config-package.in" ]; then
    echo "检查 tmp/.config-package.in 中的 nftables-nojson..."
    if grep -q "PACKAGE_nftables-nojson" tmp/.config-package.in; then
        # 备份并注释掉相关行
        cp tmp/.config-package.in tmp/.config-package.in.bak
        sed -i '/PACKAGE_nftables-nojson/d' tmp/.config-package.in
        echo "已从 tmp/.config-package.in 中删除 nftables-nojson 相关行"
    fi
fi

# --- 7. 创建 mtk_hnat 补丁文件 ---
echo "### 7. 创建 mtk_hnat 补丁文件 ###"

PATCH_DIR="${OPENWRT_DIR}/target/linux/mediatek/patches-6.12"
mkdir -p "$PATCH_DIR"

cat > "$PATCH_DIR/900-fix-hnat-missing-declarations.patch" << 'EOF'
--- a/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c
+++ b/drivers/net/ethernet/mediatek/mtk_hnat/hnat.c
@@ -1,3 +1,9 @@
+/* FIXED_BY_PATCH: 确保 u32 已定义，并将函数标记为 static */
+#include <linux/types.h>
+
+static void mtk_set_pse_drop(u32 config);
+static void hnat_cache_clr(u32 ppe_id);
+
 // SPDX-License-Identifier: GPL-2.0
 /*
  * Copyright (C) 2023 MediaTek Inc.
@@ -32,7 +38,7 @@
 
 static u32 hnat_ppe1_en = 0;
 
-void mtk_set_pse_drop(u32 config) {
+static void mtk_set_pse_drop(u32 config) {
 	u32 reg = 0, val = 0;
 
 	if (config)
@@ -138,7 +144,7 @@
 	return 0;
 }
 
-void hnat_cache_clr(u32 ppe_id)
+static void hnat_cache_clr(u32 ppe_id)
 {
 	u32 addr;
 	u32 i, j;
--- a/drivers/net/ethernet/mediatek/mtk_hnat/hnat_nf_hook.c
+++ b/drivers/net/ethernet/mediatek/mtk_hnat/hnat_nf_hook.c
@@ -341,7 +341,7 @@
 }
 
 
-void ppd_dev_setting(void)
+static void ppd_dev_setting(void)
 {
 	struct net_device *br_dev;
 	br_dev = __dev_get_by_name(&init_net, "br-lan");
@@ -466,7 +466,7 @@
 	return NOTIFY_DONE;
 }
 
-void foe_clear_entry(struct neighbour *neigh)
+static void foe_clear_entry(struct neighbour *neigh)
 {
 	u32 *daddr = (u32 *)neigh->primary_key;
 	unsigned char h_dest[ETH_ALEN];
@@ -533,7 +533,7 @@
 	return NOTIFY_DONE;
 }
 
-unsigned int mape_add_ipv6_hdr(struct sk_buff *skb, struct ipv6hdr mape_ip6h)
+static unsigned int mape_add_ipv6_hdr(struct sk_buff *skb, struct ipv6hdr mape_ip6h)
 {
 	struct ethhdr *eth = NULL;
 	struct ipv6hdr *ip6h = NULL;
@@ -573,7 +573,7 @@
 	}
 }
 
-unsigned int do_hnat_ext_to_ge(struct sk_buff *skb, const struct net_device *in,
+static unsigned int do_hnat_ext_to_ge(struct sk_buff *skb, const struct net_device *in,
 			       const char *func)
 {
 	if (hnat_priv->g_ppdev && hnat_priv->g_ppdev->flags & IFF_UP) {
@@ -603,7 +603,7 @@
 	return -1;
 }
 
-unsigned int do_hnat_ext_to_ge2(struct sk_buff *skb, const char *func)
+static unsigned int do_hnat_ext_to_ge2(struct sk_buff *skb, const char *func)
 {
 	struct ethhdr *eth = eth_hdr(skb);
 	struct net_device *dev;
@@ -671,7 +671,7 @@
 	}
 }
 
-unsigned int do_hnat_ge_to_ext(struct sk_buff *skb, const char *func)
+static unsigned int do_hnat_ge_to_ext(struct sk_buff *skb, const char *func)
 {
 	/*set where we to go*/
 	u8 index;
@@ -833,7 +833,7 @@
 	entry.ipv4_dslite.flow_lbl[2] = ip6h->flow_lbl[0];
 }
 
-unsigned int do_hnat_mape_w2l_fast(struct sk_buff *skb, const struct net_device *in,
+static unsigned int do_hnat_mape_w2l_fast(struct sk_buff *skb, const struct net_device *in,
 				   const char *func)
 {
 	struct ipv6hdr *ip6h = ipv6_hdr(skb);
@@ -882,7 +882,7 @@
 	return -1;
 }
 
-void mtk_464xlat_pre_process(struct sk_buff *skb)
+static void mtk_464xlat_pre_process(struct sk_buff *skb)
 {
 	struct foe_entry *foe;
 
@@ -1429,7 +1429,7 @@
 	return chksum_base;
 }
 
-struct foe_entry ppe_fill_L2_info(struct ethhdr *eth, struct foe_entry entry,
+static struct foe_entry ppe_fill_L2_info(struct ethhdr *eth, struct foe_entry entry,
 				  struct flow_offload_hw_path *hw_path)
 {
 	switch ((int)entry.bfib1.pkt_type) {
@@ -1459,7 +1459,7 @@
 	return entry;
 }
 
-struct foe_entry ppe_fill_info_blk(struct ethhdr *eth, struct foe_entry entry,
+static struct foe_entry ppe_fill_info_blk(struct ethhdr *eth, struct foe_entry entry,
 				   struct flow_offload_hw_path *hw_path)
 {
 	entry.bfib1.cah = 1;
@@ -2709,7 +2709,7 @@
 }
 
 
-int mtk_464xlat_fill_mac(struct foe_entry *entry, struct sk_buff *skb,
+static int mtk_464xlat_fill_mac(struct foe_entry *entry, struct sk_buff *skb,
 			 const struct net_device *out, bool l2w)
 {
 	const struct in6_addr *ipv6_nexthop;
@@ -2749,7 +2749,7 @@
 	return 0;
 }
 
-int mtk_464xlat_get_hash(struct sk_buff *skb, u32 *hash, bool l2w)
+static int mtk_464xlat_get_hash(struct sk_buff *skb, u32 *hash, bool l2w)
 {
 	struct in6_addr addr_v6, prefix;
 	struct ipv6hdr *ip6h;
@@ -2803,7 +2803,7 @@
 	return 0;
 }
 
-void mtk_464xlat_fill_info1(struct foe_entry *entry,
+static void mtk_464xlat_fill_info1(struct foe_entry *entry,
 			    struct sk_buff *skb, bool l2w)
 {
 	entry.bfib1.cah = 1;
@@ -2821,7 +2821,7 @@
 	}
 }
 
-void mtk_464xlat_fill_info2(struct foe_entry *entry, bool l2w)
+static void mtk_464xlat_fill_info2(struct foe_entry *entry, bool l2w)
 {
 	entry.ipv4_dslite.iblk2.mibf = 1;
 	entry.ipv4_dslite.iblk2.port_ag = 0xF;
@@ -2832,7 +2832,7 @@
 		entry.ipv6_6rd.iblk2.dp = NR_GMAC1_PORT;
 }
 
-void mtk_464xlat_fill_ipv4(struct foe_entry *entry, struct sk_buff *skb,
+static void mtk_464xlat_fill_ipv4(struct foe_entry *entry, struct sk_buff *skb,
 			   struct foe_entry *foe, bool l2w)
 {
 	struct iphdr *iph;
@@ -2855,7 +2855,7 @@
 	}
 }
 
-int mtk_464xlat_fill_ipv6(struct foe_entry *entry, struct sk_buff *skb,
+static int mtk_464xlat_fill_ipv6(struct foe_entry *entry, struct sk_buff *skb,
 			  struct foe_entry *foe, bool l2w)
 {
 	struct ipv6hdr *ip6h;
@@ -2906,7 +2906,7 @@
 	return 0;
 }
 
-int mtk_464xlat_fill_l2(struct foe_entry *entry, struct sk_buff *skb,
+static int mtk_464xlat_fill_l2(struct foe_entry *entry, struct sk_buff *skb,
 			const struct net_device *dev, bool l2w)
 {
 	const unsigned int *port_reg;
@@ -2939,7 +2939,7 @@
 }
 
 
-int mtk_464xlat_fill_l3(struct foe_entry *entry, struct sk_buff *skb,
+static int mtk_464xlat_fill_l3(struct foe_entry *entry, struct sk_buff *skb,
 			struct foe_entry *foe, bool l2w)
 {
 	mtk_464xlat_fill_ipv4(entry, skb, foe, l2w);
@@ -2950,7 +2950,7 @@
 	return 0;
 }
 
-int mtk_464xlat_post_process(struct sk_buff *skb, const struct net_device *out)
+static int mtk_464xlat_post_process(struct sk_buff *skb, const struct net_device *out)
 {
 	struct foe_entry *foe, entry = {};
 	u32 hash;
EOF

echo "补丁文件已创建: $PATCH_DIR/900-fix-hnat-missing-declarations.patch"

# --- 8. 确保 E87N 设备定义存在 ---
echo "### 8. 确保 E87N 设备定义在 filogic.mk 中 ###"

FILOGIC_MK="${OPENWRT_DIR}/target/linux/mediatek/image/filogic.mk"

if [ -f "$FILOGIC_MK" ]; then
    if ! grep -q "edgepi_e87n" "$FILOGIC_MK"; then
        echo "添加 E87N 设备定义到 filogic.mk..."
        cat >> "$FILOGIC_MK" << 'EOF'

# EdgePI E87N
define Device/edgepi_e87n
  DEVICE_VENDOR := EdgePI
  DEVICE_MODEL := E87N
  DEVICE_DTS := mt7987a-edgepi-e87n
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7987-eth kmod-mt7987-pinctrl
  SUPPORTED_DEVICES := edgepi,e87n
  IMAGE_SIZE := 8192k
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
endef
TARGET_DEVICES += edgepi_e87n
EOF
        echo "E87N 设备定义已添加"
    else
        echo "E87N 设备定义已存在"
    fi
else
    echo "警告: filogic.mk 不存在，尝试查找..."
    FILOGIC_MK=$(find "${OPENWRT_DIR}/target/linux/mediatek" -name "filogic.mk" 2>/dev/null | head -1)
    if [ -f "$FILOGIC_MK" ] && ! grep -q "edgepi_e87n" "$FILOGIC_MK"; then
        cat >> "$FILOGIC_MK" << 'EOF'

# EdgePI E87N
define Device/edgepi_e87n
  DEVICE_VENDOR := EdgePI
  DEVICE_MODEL := E87N
  DEVICE_DTS := mt7987a-edgepi-e87n
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7987-eth kmod-mt7987-pinctrl
  SUPPORTED_DEVICES := edgepi,e87n
  IMAGE_SIZE := 8192k
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
endef
TARGET_DEVICES += edgepi_e87n
EOF
        echo "E87N 设备定义已添加到 $FILOGIC_MK"
    fi
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

# --- 11. 验证设备配置 ---
echo "### 11. 验证设备配置 ###"
echo "检查 filogic.mk 中的设备定义:"
grep -E "edgepi_e87n|Device.*edgepi" "$FILOGIC_MK" 2>/dev/null || echo "未找到 edgepi 定义"

echo "检查 .config 中的目标设备:"
grep "CONFIG_TARGET.*edgepi" .config 2>/dev/null || echo "未找到 edgepi 配置"

echo "检查 nftables-nojson 状态:"
grep "nftables-nojson" .config 2>/dev/null || echo "nftables-nojson 未配置（正确）"

echo "### diy-part2.sh 执行完成 ###"
