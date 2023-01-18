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

# pmbootstrap -q -y -c $cfg -w $dir init
# pmbootstrap -c $cfg -y pull
pmbootstrap -y -c $cfg install
pmbootstrap -y -c $cfg export
