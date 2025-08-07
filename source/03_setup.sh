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
    mkpart primary ext4 513MiB 100% \
    set 1 boot on \
    set 1 lba on

echo "Partitions created successfully" 

# --- Set the PARTUUID ---
echo "Setting the PARTUUID..."

fdisk "${DEVICE}" <<EOF &> /dev/null
p
x
i
0x6c586e13
r
p
w
EOF

echo "PARTUUID sucessfully set!"

# --- Format partitions ---
echo "Formatting partitions..."

mkfs.vfat -F 32 -n boot ${DEVICE}1
mkfs.ext4 -L root ${DEVICE}2

echo "Partitions formatted succesfully!"

# --- Create mountpoints and mount ---
echo "Creating and mounting partitions..."

mkdir -p /mnt/root 
mount ${DEVICE}2 /mnt/root
mkdir -p /mnt/root/boot
mount ${DEVICE}1 /mnt/root/boot

echo "Partitions mounted successfully!"

# --- Get dynamic PARTUUIDs ---
PARTUUID_BOOT=$(blkid -s PARTUUID -o value ${DEVICE}1)
PARTUUID_ROOT=$(blkid -s PARTUUID -o value ${DEVICE}2)
echo "Boot PARTUUID: $PARTUUID_BOOT"
echo "Root PARTUUID: $PARTUUID_ROOT"

# --- Extract base system ---
echo "Extracting stage3 to root..."

cd build
tar -xJpf stage3-arm64-systemd-*.tar.xz -C /mnt/root --xattrs-include='*.*' --numeric-owner

echo "Stage3 extracted to root successfully!"

# --- Extract Pi boot firmware to mountpoint ---
echo "Extracting Pi boot firmware to boot..."

cp -r firmware/boot/* /mnt/root/boot/

# --- Extract nonfree firmware to mountpoint ---
mkdir -p /mnt/root/lib/firmware /mnt/root/boot/overlays
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

# --- Mount special filesystems for chroot ---
echo "Mounting /proc, /sys, /dev, and /run for chroot environment..."

mount --types proc  /proc  /mnt/root/proc
mount --rbind /sys  /mnt/root/sys
mount --make-rslave /mnt/root/sys
mount --rbind /dev  /mnt/root/dev
mount --make-rslave /mnt/root/dev
mount --bind /run /mnt/root/run || true

echo "Chroot environment mounts complete."
echo "Your Gentoo system base is now ready for configuration!"
