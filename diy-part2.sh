#!/bin/bash
# diy-part2.sh: 在加载 .config 之后执行的定制脚本

# 1. 确保 NVMe 内核模块被选中 (防御性措施)
# 如果 .config 中未包含，此处通过 sed 命令追加
if ! grep -q "CONFIG_PACKAGE_kmod-nvme=y" .config; then
    echo "CONFIG_PACKAGE_kmod-nvme=y" >> .config
    echo "CONFIG_PACKAGE_kmod-nvme-core=y" >> .config
fi

# 2. 可选: 添加其他你需要的软件包
# 例如，如果你需要文件系统工具来格式化 NVMe 硬盘:
# echo "CONFIG_PACKAGE_e2fsprogs=y" >> .config
# echo "CONFIG_PACKAGE_fdisk=y" >> .config
# echo "CONFIG_PACKAGE_blkid=y" >> .config

# 3. 运行 make defconfig 使配置变更生效
# 注意：在 P3TERX 的 workflow 中，make defconfig 会在 "Download package" 步骤执行，
# 所以这里通常不需要再执行，但为了保险可以加上。
# make defconfig

exit 0
