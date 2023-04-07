Early bootstrapping:

```sh

k3sup install --host librem13.hominions.tailnet.samcday.com --k3s-channel v1.25 --cluster --k3s-extra-args "--container-runtime-endpoint=/run/containerd/containerd.sock --node-ip=$(tailscale ip -4 librem13.hominions.tailnet.samcday.com) --flannel-backend=none --disable=traefik --disable=servicelb --disable=local-storage"
kubectl apply -f home-cluster/kube-system/ip-masq-agent.yaml

helm install flux fluxcd-community/flux2 -n flux-system --create-namespace
helm install -n kube-system tailscale-node-controller tailscale-node-controller --repo https://samcday.github.io/tailscale-node-controller

sops -d home-cluster/secrets/flux-system/age-key.yaml | kubectl apply -f-
kubectl apply -k home-cluster/kube-system
kubectl apply -k home-cluster/flux-system
