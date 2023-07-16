Early bootstrapping:

```sh

ssh root@librem13.hominions.tailnet.samcday.com kubeadm init --config /etc/kubeadm.yaml

kubectl apply -f home-cluster/kube-system/ip-masq-agent.yaml

helm install flux flux2 --repo=https://fluxcd-community.github.io/helm-charts -n flux-system --create-namespace
helm install -n kube-system tailscale-node-controller tailscale-node-controller --repo https://samcday.github.io/tailscale-node-controller

sops -d home-cluster/secrets/flux-system/age-key.yaml | kubectl apply -f-
kubectl apply -k home-cluster/kube-system
kubectl apply -k home-cluster/flux-system

helm upgrade flux flux2 --repo=https://fluxcd-community.github.io/helm-charts -n flux-system --values home-cluster/flux-values.yaml
```
