#!/bin/bash
cd "$(dirname "$0")"
set -ueo pipefail

dev=$1


# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
function bitwarden_item() {
  if [[ -z "${BW_SESSION:-}" ]]; then
    export BW_SESSION=$(bw unlock --raw)
  fi
  if [[ -z "${BW_SESSION:-}" ]]; then
    echo 'ERROR: Bitwarden vault not unlocked'
    exit 1
  fi

  bw get item "$1"
}

if [[ -z "${SKIP_BUILD:-}" ]]; then
  export TAILNET_AUTH_KEY="${TAILNET_AUTH_KEY:-$(bitwarden_item "6e22f9a5-38aa-4703-8dfd-afc200fcb3ee" | jq -r .notes)}"
  if [[ -z "$TAILNET_AUTH_KEY" ]]; then echo 'ERROR: $TAILNET_AUTH_KEY not set'; exit 1; fi

  export LUKS_KEY="${LUKS_KEY:-$(bitwarden_item "9977c9de-0946-4b4a-b8f5-b02600fb8438" | jq -r '.fields[] | select(.name == "LUKS key").value')}"
  if [[ -z "$LUKS_KEY" ]]; then echo 'ERROR: $LUKS_KEY not set'; exit 1; fi

  rm -rf mkosi.extra/
  cp -R mkosi.{real-extra,extra}

  echo -n "$TAILNET_AUTH_KEY" > mkosi.extra/etc/ts-auth-key
  mkdir mkosi.extra/etc/cryptsetup-keys.d
  echo -n "$LUKS_KEY" > mkosi.extra/etc/cryptsetup-keys.d/root.key
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
