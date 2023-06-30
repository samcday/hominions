#!/bin/bash
cd "$(dirname "$0")"
set -ueo pipefail

dev=$1

if [[ -z "${SKIP_BUILD:-}" ]]; then
  rm -rf mkosi.extra/
  cp -R mkosi.{real-extra,extra}

  for f in $(find mkosi.extra/ -type f -name '*.enc*'); do
    echo decrypting $f
    sops -i -d $f
    mv $f $(echo $f | sed s/\.enc//)
  done

  chmod 400 mkosi.extra/etc/cryptsetup-keys.d/root.key
  sudo mkosi -f --bios-size=1M
fi

if [[ -n "${BUILD_ONLY:-}" ]]; then
  exit
fi

for d in $dev*; do sudo umount $d || true; done

sudo dd if=image.raw of=$dev bs=4M status=progress conv=fsync oflag=sync

mntdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'librem13-prep')
trap "sudo umount $mntdir/boot/efi; sudo umount $mntdir" EXIT
sudo mount ${dev}3 $mntdir
sudo mount ${dev}1 $mntdir/boot/efi

# Setup GRUB
sudo cp image.initrd $mntdir/boot/initramfs-linux.img
sudo cp image.vmlinuz $mntdir/boot/vmlinuz-linux

sudo arch-chroot $mntdir grub-install --target=i386-pc $dev
sudo arch-chroot $mntdir grub-mkconfig -o /boot/grub/grub.cfg

# Tweak kernel params - read only filesystem + disable audit
sudo sed -i -e "s/quiet/audit=0/" -e "s/ rw / /" $mntdir/boot/grub/grub.cfg
