#!/bin/bash
cd "$(dirname "$0")"
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t "$0")
set -uexo pipefail

export dir=${DIR:-$tmpdir}
cfg=$dir/pmbootstrap.cfg
envsubst < pmbootstrap.cfg > $cfg

mkdir -p $dir/cache_git/
if [[ ! -d $dir/cache_git/pmaports ]]; then
    pushd $dir/cache_git
    git clone https://gitlab.com/postmarketOS/pmaports.git
    popd
fi

pmbootstrap -y -c $cfg install --password test123

echo fp2-1.hominions.tailnet.samcday.com > $dir/chroot_rootfs_fairphone-fp2/etc/hostname

pmbootstrap -y -c $cfg export --no-install
