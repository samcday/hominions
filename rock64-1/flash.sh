#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

dev=$1

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

# Bootloader setup
dd if=$mntdir/boot/rksd_loader.img of=$dev seek=64 conv=notrunc
dd if=$mntdir/boot/u-boot.itb of=$dev seek=16384 conv=notrunc
