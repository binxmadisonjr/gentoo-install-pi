#!/bin/bash
set -e 

# Load config
source "config.env"

# Run package check
source/01_package_check.sh

# Make and change to /build directory
# Assuming you have made or used git to make parent directory of RASPBERRY_PI_GENTOO
echo "Creating working environment..."
mkdir -p build
cd build

# Download the stage3 tarball
echo "Downloading the latest Gentoo stage3 tarball"
# MOVE TO CONFIG.ENV
URL="https://distfiles.gentoo.org/releases/arm64/autobuilds/current-stage3-arm64-systemd"
# MOVE TO CONFIG.ENV 
LATEST=$(wget -qO- "$URL/" | grep -o 'stage3-arm64-systemd-[0-9T]*Z\.tar\.xz' | sort | tail -n1)
wget "$URL/$LATEST"
wget "$URL/$LATEST.DIGESTS"


echo "Checking the SHA512 hash"
# Extract the expected SHA512 hash from the DIGESTS file
EXPECTED_HASH=$(awk "/SHA512 HASH/ {getline; print}" "$LATEST.DIGESTS" | grep "$LATEST\$" | awk '{print $1}')

# Get the actual SHA512 hash of the downloaded tarball
ACTUAL_HASH=$(sha512sum "$LATEST" | awk '{print $1}')

# Compare and report
if [[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]]; then
    echo "SHA512 hash verified for $LATEST."
else
    echo "SHA512 hash mismatch for $LATEST!"
    exit 1
fi

# Clone the repo (you can also download as zip and extract)
git clone --depth=1 https://github.com/raspberrypi/firmware.git

# Make the tarball of just the boot folder:
cd firmware/boot
tar -cJvf ../bootfs_$(date +%Y%m%d).tar.xz .

# Kernel sources
git clone --depth=1 https://github.com/raspberrypi/linux.git

# Firmware (boot files, already done above)
git clone --depth=1 https://github.com/raspberrypi/firmware.git

# Nonfree firmware
git clone --depth=1 https://github.com/RPi-Distro/firmware-nonfree.git

# Bluetooth firmware
git clone --depth=1 https://github.com/RPi-Distro/bluez-firmware.git

# Unmount any existing mounts (be careful)
umount ${DEVICE}* || true

# Create partition table: 512MB FAT32 boot, rest BTRFS root
parted --script $DEVICE \
    mklabel msdos \
    mkpart primary fat32 1MiB 513MiB \
    mkpart primary btrfs 513MiB 100% \
    set 1 boot on
    set 1 lba on

# Format partitions
mkfs.vfat -F 32 -n BOOT ${DEVICE}1
mkfs.btrfs -f -L ROOTFS ${DEVICE}2

# Create and mount to working dir
mkdir -p /mnt/rootfs /mnt/rootfs/boot
mount ${DEVICE}2 /mnt/rootfs
mount ${DEVICE}1 /mnt/rootfs/boot
