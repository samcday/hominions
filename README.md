## home-cluster

### Bootstrap

```sh
k3sup install --host hominion --k3s-channel v1.25 --k3s-extra-args="--node-ip=$(host hominion | sed s/'.* address '//) --flannel-backend=none --disable-network-policy --disable-helm-controller --disable-kube-proxy --disable-cloud-controller" --cluster --no-extras

export KUBECONFIG=`pwd`/kubeconfig

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm install -n kube-system cilium cilium/cilium --values kube-system/cilium/values.yaml --version 1.12.1

helm repo add fluxcd-community https://fluxcd-community.github.io/helm-charts
helm repo update fluxcd-community
helm install -n flux-system flux fluxcd-community/flux2 --create-namespace --values flux-system/values.yaml

kubectl apply -k flux-system/
```
