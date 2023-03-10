#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

wifi_pw_id="b612257d-22e8-4350-ad6a-afbf01069457" # Bitwarden vault ID of item containing wifi password

if [[ ! -f _build/.setup ]]; then
  mkdir -p _build/
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/22.03.3/targets/ipq40xx/generic/openwrt-imagebuilder-22.03.3-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/ -Jxvf -
  touch _build/.setup
fi

cp -R files _build/

# templates (with secrets)
export WIFI_PASSWORD=$(bw get item $wifi_pw_id | jq -r .notes)

for f in $(find templates -type f); do
  tgt=${f/templates/files}
  mkdir -p $(dirname _build/$tgt)
  envsubst < $f > _build/$tgt
done

# imagebuilder settings
export BIN_DIR="."
export FILES="files"
export PACKAGES=$(echo $(cat packages))
export PROFILE=avm_fritzbox-4040

(
  cd _build/
  make image PACKAGES="$PACKAGES"
)
