#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

if [[ ! -d .imagebuilder/ ]]; then
  mkdir .imagebuilder
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/22.03.3/targets/ipq40xx/generic/openwrt-imagebuilder-22.03.3-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C .imagebuilder/ -Jxvf -
fi

(
  cd .imagebuilder/
  make image PROFILE="avm_fritzbox-4040" PACKAGES="luci tailscale openssh-sftp-server" FILES="../files"
)
