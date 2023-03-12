#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
if [[ -z "${BW_SESSION:-}" ]]; then
  export BW_SESSION=$(bw unlock --raw)
fi
export WIFI_PASSWORD=${WIFI_PASSWORD:-$(bw get item "b612257d-22e8-4350-ad6a-afbf01069457" | jq -r .notes)}
export TAILNET_AUTH_KEY=${TAILNET_AUTH_KEY:-$(bw get item "6e22f9a5-38aa-4703-8dfd-afc200fcb3ee" | jq -r .notes)}
export ROOT_PW=${ROOT_PW:-$(bw get item "691cb088-5130-476c-ab7b-adb900fcdb8d" | jq -r .login.password)}

if [[ ! -f _build/.setup ]]; then
  mkdir -p _build/
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/22.03.3/targets/ipq40xx/generic/openwrt-imagebuilder-22.03.3-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/ -Jxvf -
  touch _build/.setup
fi

cp -R files _build/

for f in $(find templates -type f); do
  tgt=${f/templates/files}
  mkdir -p $(dirname _build/$tgt)
  envsubst '$WIFI_PASSWORD $TAILNET_AUTH_KEY $ROOT_PW' < $f > _build/$tgt
done

# imagebuilder settings
export BIN_DIR="."
export FILES="files"
export PACKAGES=$(echo $(cat packages))
export PROFILE=avm_fritzbox-4040
export DISABLED_SERVICES="dropbear" # using openssh-server instead

(
  cd _build/
  make image PACKAGES="$PACKAGES"
)
