#!/bin/bash
set -e 

# --- Load config ---
source "config.env"

# --- Disk setup ---
echo "Unmounting any existing mounts..."

umount ${DEVICE}1 || true
umount ${DEVICE}2 || true

echo "Unmounted any existing partitions succesfully!"

# --- Create partitions ---
echo "Creating partitions..."

parted --script $DEVICE \
    mklabel msdos \
    mkpart primary fat32 1MiB 513MiB \
    mkpart primary btrfs 513MiB 100% \
    set 1 boot on \
    set 1 lba on

echo "Partitions created successfully" 

# --- Format partitions ---
echo "Formatting partitions..."

mkfs.vfat -F 32 -n boot ${DEVICE}1
mkfs.btrfs -f -L root ${DEVICE}2

echo "Partitions formatted succesfully!"

# --- Create mountpoints and mount ---
echo "Creating and mounting partitions..."

mkdir -p /mnt/root /mnt/root/boot
mount ${DEVICE}2 /mnt/root
mount ${DEVICE}1 /mnt/root/boot

echo "Partitions mounted successfully!"

# --- Extract base system ---
echo "Extracting stage3 to root..."

tar -xJpf $LATEST -C /mnt/root --xattrs-include='*.*' --numeric-owner

echo "Stage3 extracted to root successfully!"

# --- Extract Pi boot firmware to mountpoint ---
echo "Extracting Pi boot firmware to boot..."

cp -r firmware/boot/* /mnt/root/boot/

# --- Extract nonfree firmware to mountpoint ---
echo "Copying nonfree firmware to /lib/firmware..."

cp -r firmware-nonfree/* /mnt/root/lib/firmware/ || true

# --- Extract bluetooth firmware to mountpoint ---
echo "Copying bluetooth firmware to /lib/firmware..."
cp -r bluez-firmware/* /mnt/root/lib/firmware/ || true

# --- Kernel build/install ---
echo "Building and installing the kernel and modules (this may take a while)..."
cd linux

# --- Use Pi default config ---
KERNEL=kernel8
make bcm2711_defconfig      # For Raspberry Pi 4/5, adjust for your board if needed
make -j$(nproc)
make modules_install INSTALL_MOD_PATH=/mnt/root
cp arch/arm64/boot/Image /mnt/root/boot/$KERNEL.img
cp arch/arm64/boot/dts/broadcom/*.dtb /mnt/root/boot/
cp arch/arm64/boot/dts/overlays/*.dtb* /mnt/root/boot/overlays/
cp arch/arm64/boot/dts/overlays/README /mnt/root/boot/overlays/

cd ..

echo "Kernel build and install complete."
echo "Your Gentoo system base is now ready for chroot configuration."
