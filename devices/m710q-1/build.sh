#!/bin/bash
cd "$(dirname "$0")"
set -ueo pipefail

dev=$1

if [[ -z "${SKIP_BUILD:-}" ]]; then
  sops -d mkosi.rootpw.enc > mkosi.rootpw
  chmod 600 mkosi.rootpw

  rm -rf mkosi.extra/
  cp -R mkosi.{real-extra,extra}

  for f in $(find mkosi.extra/ -type f -name '*.enc*'); do
    echo decrypting $f
    sops -i -d $f
    mv $f $(echo $f | sed s/\.enc//)
  done

  chmod 400 mkosi.extra/etc/cryptsetup-keys.d/root.key
  sudo mkosi -f
fi

if [[ -n "${BUILD_ONLY:-}" ]]; then
  exit
fi

for d in $dev*; do sudo umount $d || true; done

sudo dd if=image.raw of=$dev bs=4M status=progress conv=fsync oflag=sync
