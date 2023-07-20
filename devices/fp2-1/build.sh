#!/bin/bash
cd "$(dirname "$0")"
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t "$0")
set -uexo pipefail

export dir=${DIR:-$tmpdir}

# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
if [[ -z "${BW_SESSION:-}" ]]; then
  export BW_SESSION=$(bw unlock --raw)
fi

export TAILNET_AUTH_KEY=${TAILNET_AUTH_KEY:-$(bw get item "6e22f9a5-38aa-4703-8dfd-afc200fcb3ee" | jq -r .notes)}
export ROOT_PW=${ROOT_PW:-$(bw get item "ec637cc6-b6f1-4a0c-ad60-afd600ea8152" | jq -r .login.password)}

cfg=$dir/pmbootstrap.cfg
envsubst < pmbootstrap.cfg > $cfg

mkdir -p $dir/cache_git/
if [[ ! -d $dir/cache_git/pmaports ]]; then
    pushd $dir/cache_git
    git clone https://gitlab.com/postmarketOS/pmaports.git
    popd
fi

pmbootstrap="pmbootstrap -y -c $cfg"

trap "$pmbootstrap shutdown" EXIT

$pmbootstrap install --password $ROOT_PW --no-firewall

chroot=$dir/chroot_rootfs_fairphone-fp2

$pmbootstrap chroot -r sh <<SETUP
set -uexo pipefail
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


cat > /etc/local.d/prep-containerd.start <<HERE
set -uexo pipefail
mkdir -p /etc/containerd
containerd config default \
    | sed 's/bin_dir = .*/bin_dir = "\/usr\/libexec\/cni"/g' \
    > /etc/containerd/config.toml
rc-update add containerd default
service containerd restart
rm /etc/local.d/prep-containerd.start
HERE
chmod +x /etc/local.d/prep-containerd.start

rc-update add kubelet default
rc-update add tailscale default

cat > /etc/local.d/tailscale-up.start <<HERE
set -uexo pipefail
tailscale up --accept-routes --accept-dns --login-server=https://samcday-headscale.fly.dev --auth-key=${TAILNET_AUTH_KEY}
rm /etc/local.d/tailscale-up.start
HERE
chmod +x /etc/local.d/tailscale-up.start

echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel-nopasswd

echo 'ip route add default via 172.16.42.2 dev usb0' > /etc/local.d/usb_internet.start
echo 'echo nameserver 1.1.1.1 > /etc/resolv.conf' >> /etc/local.d/usb_internet.start
chmod +x /etc/local.d/usb_internet.start
SETUP

$pmbootstrap install --password $ROOT_PW --no-firewall

if [[ -n "${FLASH:-}" ]]; then
    $pmbootstrap flasher flash_kernel
    $pmbootstrap flasher flash_rootfs --partition userdata
else
    $pmbootstrap export
fi
