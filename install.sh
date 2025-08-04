#!/bin/bash
set -e 

# Load config
source "config.env"

# Run package check
"source/01_package_check.sh"



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
