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

pmbootstrap="pmbootstrap -y -c $cfg"

$pmbootstrap install --password test123 --no-firewall

chroot=$dir/chroot_rootfs_fairphone-fp2

sh <<SETUP
cat > /etc/modules-load.d/k8s.conf <<HERE
overlay
br_netfilter
HERE

cat > /etc/sysctl.d/k8s.conf <<HERE
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.ipv4.ip_forward=1
HERE

cat > /etc/local.d/restartnm.start <<HERE
service networkmanager restart
service ntpd restart
HERE
chmod +x /etc/local.d/restartnm.start

sed -i -e 's/bin_dir = .*/bin_dir = "\/opt\/cni\/bin"/g' /etc/containerd/config.toml
rc-update add containerd
rc-update add kubelet
rc-update add tailscale
SETUP

$pmbootstrap install --password test123 --no-firewall

$pmbootstrap export
