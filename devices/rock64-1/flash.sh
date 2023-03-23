#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
if [[ -z "${BW_SESSION:-}" ]]; then
  export BW_SESSION=$(bw unlock --raw)
fi

# Secrets
export TAILNET_AUTH_KEY=${TAILNET_AUTH_KEY:-$(bw get item "6e22f9a5-38aa-4703-8dfd-afc200fcb3ee" | jq -r .notes)}

dev=$1

for d in $dev*; do umount $d || true; done

sfdisk $dev <<HERE
label: dos
unit: sectors
sector-size: 512
$dev : start=32768, size=124702720, type=83
HERE

wipefs -a ${dev}1
mkfs.ext4 ${dev}1

mntdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'rock64-flashy-boi')
trap "umount $mntdir" EXIT
mount ${dev}1 $mntdir

rsync -avP image/ $mntdir/

echo $TAILNET_AUTH_KEY > $mntdir/etc/ts-auth-key

# Bootloader setup
dd if=$mntdir/boot/rksd_loader.img of=$dev seek=64 conv=notrunc
dd if=$mntdir/boot/u-boot.itb of=$dev seek=16384 conv=notrunc
