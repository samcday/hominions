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

pmbootstrap -y -c $cfg install --password test123 --no-firewall

chroot=$dir/chroot_rootfs_fairphone-fp2

sudo cat > $chroot/etc/modules-load.d/k8s.conf <<HERE
overlay
br_netfilter
HERE

sudo cat > $chroot/etc/sysctl.d/k8s.conf <<HERE
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.ipv4.ip_forward=1
HERE

sudo cat > $chroot/etc/local.d/restartnm.start <<HERE
service networkmanager restart
service ntpd restart
HERE
chmod +x $chroot/etc/local.d/restartnm.start

sed -i 's/bin_dir = .*/bin_dir = "/opt/cni/bin"/g' $chroot/etc/containerd/config.toml

pmbootstrap chroot -r rc-update add containerd
pmbootstrap chroot -r rc-update add kubelet
pmbootstrap chroot -r rc-update add tailscale

pmbootstrap -y -c $cfg install --password test123 --no-firewall

pmbootstrap -y -c $cfg export
