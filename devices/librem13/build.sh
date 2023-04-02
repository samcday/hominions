#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
if [[ -z "${BW_SESSION:-}" ]]; then
  export BW_SESSION=$(bw unlock --raw)
fi

export TAILNET_AUTH_KEY=${TAILNET_AUTH_KEY:-$(bw get item "6e22f9a5-38aa-4703-8dfd-afc200fcb3ee" | jq -r .notes)}

dev=$1

for d in $dev*; do umount $d || true; done

# dd if=image.raw of=$dev bs=4M status=progress
# sync

mntdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'librem13-prep')
trap "umount $mntdir/boot/efi; umount $mntdir" EXIT
mount ${dev}3 $mntdir
mount ${dev}1 $mntdir/boot/efi

echo $TAILNET_AUTH_KEY > $mntdir/etc/ts-auth-key

# Setup GRUB
cp image.initrd $mntdir/boot/initramfs-linux.img
cp image.vmlinuz $mntdir/boot/vmlinuz-linux

arch-chroot $mntdir grub-install --target=i386-pc $dev
arch-chroot $mntdir grub-mkconfig -o /boot/grub/grub.cfg
