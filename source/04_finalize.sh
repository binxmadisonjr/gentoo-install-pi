#!/bin/bash
set -e

# --- Load config ---
source "config.env"

ROOT=/mnt/root
BOOT=/mnt/root/boot

# --- Set root password (hashed) ---
echo "Setting root password..."
ROOT_PASSWORD_SALT=$(openssl rand -base64 12)
ROOT_PASSWORD_HASHED=$(openssl passwd -6 -salt "${ROOT_PASSWORD_SALT}" "${ROOT_PASSWORD}")
USER="root"
sed -i "s|^${USER}:[^:]*:|${USER}:${ROOT_PASSWORD_HASHED}:|" "$ROOT/etc/shadow"

# --- Set hostname ---
echo "$HOSTNAME" > "$ROOT/etc/hostname"

# --- Set keymap ---
sed -i "s/^KEYMAP=.*/KEYMAP=\"$KEYMAP\"/" "$ROOT/etc/conf.d/keymaps"

# --- Add network symlink ---
ln -sf net.lo "$ROOT/etc/init.d/net.end0"

# --- Set up fstab ---
echo "PARTUUID=6c586e13-01   /boot   vfat    defaults,auto,noatime,umask=0022,uid=0,gid=100   0 0" >> "$ROOT/etc/fstab"

# --- Update sshd config for root login ---
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' "$ROOT/etc/ssh/sshd_config"

# --- Optionally set up make.conf with parallelism and binhost ---
cat <<EOF >> "$ROOT/etc/portage/make.conf"

MAKEOPTS="-j$(nproc)"
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --load-average=$(nproc)"
FEATURES="\${FEATURES} getbinpkg"
PORTAGE_BINHOST="https://dev.drassal.net/genpi64/pi64pie_20250115_binpkgs"
EOF

# --- Optionally add overlay repo configs ---
mkdir -p "$ROOTFS/etc/portage/repos.conf"
cat <<EOF > "$ROOTFS/etc/portage/repos.conf/gentoo.conf"
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = rsync
sync-uri = rsync://rsync.gentoo.org/gentoo-portage
auto-sync = yes
EOF

cat <<EOF > "$ROOTFS/etc/portage/repos.conf/genpi64.conf"
[DEFAULT]
main-repo = gentoo

[genpi64]
location = /var/db/repos/genpi64
sync-type = rsync
sync-uri = rsync://dev.drassal.net/genpi64-portage_20250115
priority = 100
auto-sync = yes
EOF

# --- Optionally fix cmdline.txt (may require custom logic for your setup) ---
CMDLINE="console=serial0,115200 console=tty1 dwc_otg.lpm_enable=0 root=PARTUUID=6c586e13-02 rootfstype=btrfs rootdelay=0 fsck.repair=yes rootwait"
echo "$CMDLINE" > "$BOOT/cmdline.txt"

# --- Unmount and clean up ---
echo "Syncing and unmounting..."
sync
umount "$BOOT" || true
umount "$ROOT" || true

echo "All done! You can now boot your Raspberry Pi."
