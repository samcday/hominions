#!/bin/bash
set -uexo pipefail

# boot da boot cluster!

ssh="ssh -l root"
scp="scp -o User=root"

# kubeadm init on host1 if necessary
host1=n1.boot-cluster.tailnet.samcday.com
until $ssh -S none $host1 date; do
  sleep 1
done

export IP6=$($ssh $host1 tailscale ip -6)
cat kubelet-config.yaml kubeadm-config.yaml kubeadm-init.yaml | envsubst | $ssh $host1 'cat > kubeadm-config.yaml'

# hax
if ! $ssh $host1 stat /etc/resolv.conf.kubelet; then
  scp resolv.conf.kube $host1:/etc/
fi

if ! $ssh $host1 'stat /etc/kubernetes/admin.conf'; then
  $ssh $host1 ash <<INIT
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.default.forwarding    = 1
EOF

service sysctl restart
INIT
  $ssh $host1 kubeadm init --config kubeadm-config.yaml -v=10
fi

# grab kubeconfig from host1
export KUBECONFIG=/tmp/hominions-boot-kubeconfig
$scp $host1:/etc/kubernetes/admin.conf $KUBECONFIG

# make sure control plane on host1 is up
until kubectl get nodes; do
  sleep 1
done

# deploy flannel
kubectl apply -f flannel.yaml

# upload control-plane certs with newly generated cert-key via host1
export CERT_KEY=$(kubeadm certs certificate-key)
$ssh $host1 kubeadm init phase upload-certs --upload-certs --certificate-key $CERT_KEY

# grab token and sha from host1
export TOKEN=$($ssh $host1 kubeadm token create)
export CA_HASH=$($ssh $host1 "cat /etc/kubernetes/pki/ca.crt  | openssl x509 -pubkey | openssl ec -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")

exit

# join host2
host2=n2.boot-cluster.tailnet.samcday.com
until $ssh -S none $host2 date; do
  sleep 1
done

# hax
if ! $ssh $host2 stat /etc/resolv.conf.kubelet; then
  scp resolv.conf.kube $host2:/etc/
fi

export IP6=$($ssh $host2 tailscale ip -6)
cat kubelet-config.yaml kubeadm-config.yaml kubeadm-join.yaml | envsubst | $ssh $host2 'cat > kubeadm-config.yaml'
if ! $ssh $host2 'stat /etc/kubernetes/admin.conf'; then
  $ssh $host2 ash <<INIT
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.default.forwarding    = 1
EOF

service sysctl restart
INIT
  $ssh $host2 kubeadm join --config kubeadm-config.yaml -v=10
fi
