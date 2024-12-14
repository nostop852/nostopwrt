#!/bin/bash

# 进入主目录
cd ~ || exit

# 检测 openwrt1 文件夹是否存在，如果存在则删除
if [ -d "openwrt1" ]; then
    echo "检测到 openwrt1 文件夹，正在删除..."
    rm -rf openwrt1
    if [ $? -ne 0 ]; then
        echo "删除 openwrt1 文件夹失败，退出脚本。"
        exit 1
    fi
    echo "openwrt1 文件夹已删除。"
fi

# 下载 openwrt1 官方仓库
echo "正在下载 openwrt 官方仓库..."
git clone -b v23.05.4 --single-branch --depth=1 https://github.com/openwrt/openwrt.git openwrt1

# 检测仓库是否正确下载
if [ $? -ne 0 ]; then
    echo "下载 openwrt 仓库失败，退出脚本。"
    exit 1
fi
echo "openwrt 仓库下载成功。"

cd ~/openwrt1 || exit
# 设置魔法值
curl -s https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-23.05.5-x86-64.manifest | grep kernel | awk '{print $3}' | awk -F- '{print $3}' > vermagic


# 修改内核配置文件
# 注释掉特定行并在其下方添加新行
sed -i '/grep \=\[ym\]/ { s/^/# /; a \
cp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic
}' include/kernel-defaults.mk

# 提示完成
echo "内核配置文件已自动修改。"

# 函数：执行 ./scripts/feeds update -a 并在失败时重试
retry_feeds_update() {
    local attempt=0
    local max_attempts=5
    local success=0

    while [ $attempt -lt $max_attempts ]; do
        echo "尝试执行 ./scripts/feeds update -a (尝试次数: $((attempt + 1)))..."
        ./scripts/feeds update -a

        # 如果成功退出循环
        if [ $? -eq 0 ]; then
            echo "feeds 更新成功。"
            success=1
            break
        fi

        attempt=$((attempt + 1))
        echo "feeds 更新失败，等待 2 秒后重试..."
        sleep 2
    done

    # 如果五次都失败，则退出脚本
    if [ $success -ne 1 ]; then
        echo "尝试 5 次 ./scripts/feeds update -a 失败，退出脚本。"
        exit 1
    fi
}


# 添加第三方源到 feeds.conf.default
echo "添加第三方源"
sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

# 下载并更新所有 feeds（此操作不能省略）
retry_feeds_update

# 安装所有 feeds
./scripts/feeds install -a
# 再安装一次 feeds
./scripts/feeds install -a

# 删除冲突app
cd ~/openwrt1/feeds/kenzo
rm -rf luci-app-dockerman luci-theme-argon luci-theme-argone luci-app-argon-config luci-app-argone-config
echo "已经删除冲突的dockerman argon argone"

# 进入 nostopwrt 目录，将文件拷贝到源码目录
cd ~/nostopwrt || exit
cp banner ~/openwrt1/package/base-files/files/etc
cp -r gowebdav vlmcsd ~/openwrt1/feeds/packages/net/
cp -r ipv6-helper adbyby ~/openwrt1/package/
cp -r luci/* ~/openwrt1/feeds/luci/applications

# 返回到 openwrt1 目录
cd ~/openwrt1 || exit

# 删除低版本 golang
rm -rf feeds/packages/lang/golang

# 下载高版本 golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang
# 等待 2 秒
echo "等待 2 秒..."
sleep 2

# 下载 turboacc 插件并执行安装
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh

# 修改dockerd编译依赖
# 指定 Config.in 文件路径
CONFIG_IN_PATH="feeds/packages/utils/dockerd/Config.in"
# 注释掉 select PACKAGE_cgroupfs-mount 行
echo "正在注释掉 Config.in 文件中的 'select PACKAGE_cgroupfs-mount'..."
sed -i '/^select PACKAGE_cgroupfs-mount/s/^/#/' $CONFIG_IN_PATH

# 修改homeproxy文件
FILE="feeds/small/luci-app-homeproxy/po/zh_Hans/homeproxy.po"
# 确保文件存在
if [ ! -f $FILE ]; then
    echo "File not found: $FILE"
    exit 1
fi
# 查找第二个出现的 ' ImmortalWrt '（前后各一个空格），并将其删除
sed -i '0,/ ImmortalWrt /{s//PLACEHOLDER/;t;d};0,/PLACEHOLDER/{s// /}' $FILE

echo "成功删除了homeproxy中的 ImmortalWrt 标记。"


# 修改ssr文件
FILE=~/openwrt1/feeds/small/luci-app-ssr-plus/Makefile
# 使用 sed 命令注释掉指定行
sed -i.bak '/^ +PACKAGE_$(PKG_NAME)_INCLUDE_libustream-openssl:libustream-openssl/ s/^/# /' "$FILE"

echo "已注释指定行，并创建了备份文件 ${FILE}.bak"

# 精确修改默认 IP 和主机名
CONFIG_GENERATE="package/base-files/files/bin/config_generate"
sed -i 's/\(ipaddr:\)-"192.168.1.1"/\1-"192.168.0.222"/' "$CONFIG_GENERATE"
sed -i "s/\(hostname=\)'openwrt'/\1'OpenZhao'/" "$CONFIG_GENERATE"

echo "默认 IP 和主机名已修改完成，开始重新更新和安装 feeds..."

# 再次更新所有 feeds
./scripts/feeds update -a

# 检测 feeds 更新是否成功
if [ $? -ne 0 ]; then
    echo "feeds 更新失败，退出脚本。"
    exit 1
fi

echo "feeds 更新成功，继续执行安装..."

# 安装所有 feeds
./scripts/feeds install -a

# 检测 feeds 安装是否成功
if [ $? -ne 0 ]; then
    echo "feeds 安装失败，退出脚本。"
    exit 1
fi

# 再次更新所有 feeds并安装
./scripts/feeds update -a
./scripts/feeds install -a

echo "feeds 安装成功，所有定制工作已完成。"

echo "开始配置需要编译要求。"
cp ~/nostopwrt/.config ~/openwrt1
make menuconfig
