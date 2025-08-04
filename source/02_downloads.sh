#!/bin/bash
set -e
source "config.env"

# Make and change to /build directory
echo "Creating working environment..."
mkdir -p build
cd build

# Download the stage3 tarball
echo "Downloading the latest Gentoo stage3 tarball..."
URL="https://distfiles.gentoo.org/releases/arm64/autobuilds/current-stage3-arm64-systemd"
LATEST=$(wget -qO- "$URL/" | grep -o 'stage3-arm64-systemd-[0-9T]*Z\.tar\.xz' | sort | tail -n1)
wget "$URL/$LATEST"
wget "$URL/$LATEST.DIGESTS"

# Compare and report
echo "Checking the SHA512 hash..."
EXPECTED_HASH=$(awk "/SHA512 HASH/ {getline; print}" "$LATEST.DIGESTS" | grep "$LATEST\$" | awk '{print $1}')
ACTUAL_HASH=$(sha512sum "$LATEST" | awk '{print $1}')
if [[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]]; then
    echo "SHA512 hash verified for $LATEST."
else
    echo "SHA512 hash mismatch for $LATEST!"
    exit 1
fi

# Clone the raspberry pi firmware repo
echo "Cloning the Raspberry Pi firmware..."
git clone --depth=1 https://github.com/raspberrypi/firmware.git

# Nonfree firmware
echo "Cloning the Raspberry Pi nonfree-firmware..."
git clone --depth=1 https://github.com/RPi-Distro/firmware-nonfree.git

# Make the tarball of just the boot folder:
echo "Making creating the bootfs tarball..."
cd firmware/boot
tar -cJvf ../bootfs_$(date +%Y%m%d).tar.xz .
cd ../..

# Kernel sources
echo "Cloning the Raspberry Pi kernel sources..."
git clone --depth=1 https://github.com/raspberrypi/linux.git

# Bluetooth firmware
echo "Cloning the Raspberry Pi bluetooth firmware..."
git clone --depth=1 https://github.com/RPi-Distro/bluez-firmware.git
