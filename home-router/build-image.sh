#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

if [[ ! -f _build/.setup ]]; then
  mkdir -p _build/
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/22.03.3/targets/ipq40xx/generic/openwrt-imagebuilder-22.03.3-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/ -Jxvf -
  touch _build/.setup
fi

cp -R files/ _build/

export BIN_DIR="."
export FILES="files"
export PACKAGES=$(echo $(cat packages))
export PROFILE=avm_fritzbox-4040

(
  env
  exit
  cd _build/
  make image
)
