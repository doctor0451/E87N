#!/bin/bash
# diy-part2.sh - E87N 专属定制

# 进入源码目录
cd openwrt || exit

# --- 1. 强化禁用Wi-Fi相关配置 (覆盖可能残留的选项) ---
echo "### 强制禁用Wi-Fi模块 ###"
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

# --- 2. 确保E87N设备被正确选择 ---
echo "### 设置E87N为目标设备 ###"
./scripts/config --set-val CONFIG_TARGET_mediatek_filogic_DEVICE_edgepi_e87n y

# --- 3. 清理可能因WiFi驱动产生的依赖冲突 ---
echo "### 清理WiFi驱动残留 ###"
make package/mtk/drivers/mt_wifi7/clean -j1 || true
make package/mtk/drivers/mt_hwifi/clean -j1 || true

# --- 4. 添加E87N屏幕和风扇配置 (如果源码中未包含) ---
# 注意：如果你的DTS已定义了这些，此步骤可能不需要。
# 这里演示如何通过UCI默认配置来确保相关服务启用。
echo "### 预设屏幕与风扇配置 ###"
mkdir -p files/etc/init.d
mkdir -p files/etc/config

# 创建风扇控制脚本 (示例)
cat << "EOF" > files/etc/init.d/fancontrol
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -e /sys/class/thermal/thermal_zone0/temp ] || return
    echo "Enabling PWM fan control..."
    # 简单示例：根据CPU温度调节风扇PWM
    while true; do
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        if [ $TEMP -gt 80000 ]; then
            echo 255 > /sys/class/pwm/pwmchip0/pwm1/duty_cycle
        elif [ $TEMP -gt 60000 ]; then
            echo 128 > /sys/class/pwm/pwmchip0/pwm1/duty_cycle
        else
            echo 0 > /sys/class/pwm/pwmchip0/pwm1/duty_cycle
        fi
        sleep 10
    done &
}
EOF
chmod +x files/etc/init.d/fancontrol

# 注意：请根据实际使用的PWM芯片和屏幕设备节点调整上述路径。

echo "### diy-part2.sh 执行完成 ###"
