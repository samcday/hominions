#!/bin/bash
set -uexo pipefail


rm -rf files-decrypted/
cp -R files{,-decrypted}

for f in $(find files-decrypted/ -type f -name '*.enc*'); do
  echo decrypting $f
  sops -i -d $f
  mv $f $(echo $f | sed s/\.enc//)
done

BUTANE_CONFIG="`pwd`/config.bu"
IGNITION_CONFIG="`pwd`/config.ign"

podman run --rm -v `pwd`:/data quay.io/coreos/butane:release \
  -d /data/files-decrypted --pretty --strict -o /data/config.ign /data/config.bu
