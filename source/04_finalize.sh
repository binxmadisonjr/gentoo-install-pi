#!/bin/bash
set -e

# --- Load config ---
source "config.env"

ROOT=/mnt/root
BOOT=/mnt/root/boot

# --- Detect PARTUUIDs ---
PARTUUID_BOOT=$(blkid -s PARTUUID -o value ${DEVICE}1)
PARTUUID_ROOT=$(blkid -s PARTUUID -o value ${DEVICE}2)

# --- Set root password (hashed) ---
echo "Setting root password..."
ROOT_PASSWORD_SALT=$(openssl rand -base64 12)
ROOT_PASSWORD_HASHED=$(openssl passwd -6 -salt "${ROOT_PASSWORD_SALT}" "${ROOT_PASSWORD}")
USER="root"
sed -i "s|^${USER}:[^:]*:|${USER}:${ROOT_PASSWORD_HASHED}:|" "$ROOT/etc/shadow"

# --- Set hostname ---
echo "$HOSTNAME" > "$ROOT/etc/hostname"

# --- Set keymap ---
if [ ! -f "$ROOT/etc/conf.d/keymaps" ]; then
    echo "KEYMAP=\"$KEYMAP\"" > "$ROOT/etc/conf.d/keymaps"
else
    sed -i "s/^KEYMAP=.*/KEYMAP=\"$KEYMAP\"/" "$ROOT/etc/conf.d/keymaps"
fi

# --- Add network symlink ---
ln -sf net.lo "$ROOT/etc/init.d/net.end0"

# --- Set up fstab (dynamic PARTUUIDs + required mounts) ---
cat <<EOF > "$ROOT/etc/fstab"
PARTUUID=$PARTUUID_BOOT   /boot   vfat    defaults,auto,noatime,umask=0022,uid=0,gid=100   0 0
PARTUUID=$PARTUUID_ROOT   /       ext4    defaults,noatime   0 1
proc            /proc       proc    defaults          0 0
sysfs           /sys        sysfs   defaults          0 0
devtmpfs        /dev        devtmpfs   defaults       0 0
EO

# --- Update sshd config for root login ---
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' "$ROOT/etc/ssh/sshd_config"

# --- make.conf with parallelism and binhost ---
cat <<EOF >> "$ROOT/etc/portage/make.conf"

MAKEOPTS="-j$(nproc)"
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc)"
FEATURES="\${FEATURES} getbinpkg"
PORTAGE_BINHOST="https://dev.drassal.net/genpi64/pi64pie_20250115_binpkgs"
EOF

# --- Overlay repo configs ---
mkdir -p "$ROOT/etc/portage/repos.conf"
cat <<EOF > "$ROOT/etc/portage/repos.conf/gentoo.conf"
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = rsync
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
auto-sync = yes
EOF

cat <<EOF > "$ROOT/etc/portage/repos.conf/genpi64.conf"
[DEFAULT]
main-repo = gentoo

[genpi64]
location = /var/db/repos/genpi64
sync-type = rsync
sync-uri = rsync://dev.drassal.net/genpi64-portage_20250115
priority = 100
auto-sync = yes
EOF

# --- Create cmdline.txt (dynamic PARTUUID) ---
CMDLINE="console=serial0,115200 console=tty1 root=PARTUUID=$PARTUUID_ROOT rootfstype=ext4 rootdelay=0 fsck.repair=yes rootwait"
echo "$CMDLINE" > "$BOOT/cmdline.txt"

# --- Create config.txt ---
cat <<EOF > "$BOOT/config.txt"
arm_64bit=1
enable_uart=1
kernel=kernel8.img
dtoverlay=disable-bt
EOF

# --- Chroot and run time sync, emerge --sync, install iwctl ---
echo "Entering chroot to set timezone, sync portage, and install iwctl..."

cat <<'EOFCHROOT' | chroot $ROOT /bin/bash
set -e

# Set the timezone (America/Chicago)
echo "Setting timezone to America/Chicago..."
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "America/Chicago" > /etc/timezone

# Set system time via ntpd or chronyd if available, else warn
if command -v ntpd >/dev/null 2>&1; then
  ntpd -gq || true
elif command -v chronyd >/dev/null 2>&1; then
  chronyd -q "server pool.ntp.org iburst" || true
else
  echo "WARNING: No ntpd or chronyd, time may be off until you set it."
fi

# Sync the portage tree
echo "Running emerge --sync..."
emerge --sync

# Install iwctl (iwd)
echo "Installing net-wireless/iwd..."
emerge --ask=n net-wireless/iwd

echo "All chroot configuration complete!"
EOFCHROOT

# --- Unmount and clean up ---
echo "Syncing and unmounting..."
sync
umount "$BOOT" || true
umount "$ROOT" || true

echo "All done! You can now boot your Raspberry Pi."
