#!/bin/bash

# Enter home directory
cd ~ || exit

# Check if the openwrt folder exists, and if it does, delete it
if [ -d "openwrt" ]; then
    echo "Detected openwrt folder, deleting..."
    rm -rf openwrt
    if [ $? -ne 0 ]; then
        echo "Failed to delete openwrt folder, exiting script."
        exit 1
    fi
    echo "openwrt folder deleted."
fi

# Download the official OpenWrt repository
echo "Downloading the official OpenWrt repository..."
git clone -b v23.05.4 --single-branch --depth=1 https://github.com/openwrt/openwrt.git

# Check if the repository was downloaded correctly
if [ $? -ne 0 ]; then
    echo "Failed to download the OpenWrt repository, exiting script."
    exit 1
fi
echo "OpenWrt repository downloaded successfully."

cd ~/openwrt || exit
# Set magic value
curl -s https://downloads.openwrt.org/releases/23.05.4/targets/x86/64/openwrt-23.05.4-x86-64.manifest | grep kernel | awk '{print $3}' | awk -F- '{print $3}' > vermagic

# Modify kernel configuration file
# Comment out a specific line and add a new line below it
sed -i '/grep \=\[ym\]/ { s/^/# /; a \
cp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic
}' include/kernel-defaults.mk

# Prompt completion
echo "Kernel configuration file has been automatically modified."

# Function: Run ./scripts/feeds update -a and retry if it fails
retry_feeds_update() {
    local attempt=0
    local max_attempts=5
    local success=0

    while [ $attempt -lt $max_attempts ]; do
        echo "Attempting to run ./scripts/feeds update -a (Attempt: $((attempt + 1)))..."
        ./scripts/feeds update -a

        # Exit the loop if successful
        if [ $? -eq 0 ]; then
            echo "Feeds updated successfully."
            success=1
            break
        fi

        attempt=$((attempt + 1))
        echo "Feeds update failed, retrying in 2 seconds..."
        sleep 2
    done

    # If all 5 attempts fail, exit the script
    if [ $success -ne 1 ]; then
        echo "Failed to run ./scripts/feeds update -a after 5 attempts, exiting script."
        exit 1
    fi
}

# Add third-party sources to feeds.conf.default
echo "Adding third-party sources"

# Download and update all feeds
retry_feeds_update

# Install all feeds
./scripts/feeds install -a
# Install feeds again
./scripts/feeds install -a

# Remove conflicting apps

# Enter nostopwrt directory and copy files to source directory
cd ~/nostopwrt || exit
cp -r gowebdav vlmcsd ~/openwrt/feeds/packages/net/
cp -r ipv6-helper adbyby ~/openwrt/package/
cp -r luci/* ~/openwrt/feeds/luci/applications

# Return to the openwrt directory
cd ~/openwrt || exit

# Remove the lower version of golang
rm -rf feeds/packages/lang/golang

# Download the higher version of golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang
# Wait for 2 seconds
echo "Waiting for 2 seconds..."
sleep 2

# Download the turboacc plugin and install it
curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh


# Modify dockerd build dependencies
# Specify the Config.in file path
CONFIG_IN_PATH="feeds/packages/utils/dockerd/Config.in"
# Comment out the line 'select PACKAGE_cgroupfs-mount'
echo "Commenting out 'select PACKAGE_cgroupfs-mount' in the Config.in file..."
sed -i '/^select PACKAGE_cgroupfs-mount/s/^/#/' $CONFIG_IN_PATH

# Modify the hostname
CONFIG_GENERATE="package/base-files/files/bin/config_generate"
sed -i "s/\(hostname=\)'OpenWrt'/\1'NostopWrt'/" "$CONFIG_GENERATE"
echo "Default hostname have been modified. Starting to update and install feeds again..."


# Update all feeds again
./scripts/feeds update -a

# Check if the feeds update was successful
if [ $? -ne 0 ]; then
    echo "Feeds update failed, exiting script."
    exit 1
fi

echo "Feeds updated successfully, proceeding with installation..."

# Install all feeds
./scripts/feeds install -a

# Check if the feeds installation was successful
if [ $? -ne 0 ]; then
    echo "Feeds installation failed, exiting script."
    exit 1
fi

# Update all feeds and install them again
./scripts/feeds update -a
./scripts/feeds install -a

echo "Feeds installation successful, all customizations are complete."

echo "Starting configuration for build requirements."
#cp ~/nostopwrt/.config ~/openwrt
make menuconfig
