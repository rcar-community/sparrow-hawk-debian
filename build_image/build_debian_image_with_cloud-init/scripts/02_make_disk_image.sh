#!/usr/bin/env bash
set -euo pipefail

ROOTFS="$1"
IMG="$2"
SIZE_GIB="$3"
BOOT_MIB="$4"

truncate -s "${SIZE_GIB}G" "$IMG"

# パーティション（msdos: boot FAT + root ext4）
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 1MiB "${BOOT_MIB}MiB"
parted -s "$IMG" mkpart primary ext4  "${BOOT_MIB}MiB" 100%

LOOP=$(losetup --find --show --partscan "$IMG")
BOOT_DEV="${LOOP}p1"
ROOT_DEV="${LOOP}p2"

mkfs.vfat -n bootfs "$BOOT_DEV"        # bootfsラベル
mkfs.ext4 -L rootfs "$ROOT_DEV"        # rootfsラベル

mkdir -p /mnt/myos-boot /mnt/myos-root
mount "$ROOT_DEV" /mnt/myos-root
mkdir -p /mnt/myos-root/boot
mount "$BOOT_DEV" /mnt/myos-root/boot

# rootfs投入
rsync -aHAX --numeric-ids "${ROOTFS}/" /mnt/myos-root/

# fstab（LABELでマウント）
cat > /mnt/myos-root/etc/fstab <<'EOF'
LABEL=rootfs  /      ext4  defaults  0  1
LABEL=bootfs  /boot   vfat  defaults  0  2
EOF

sync
umount /mnt/myos-root/boot
umount /mnt/myos-root
losetup -d "$LOOP"

