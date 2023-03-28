Early bootstrapping:

 * `k3sup install --host rock64-1.hominions.tailnet.samcday.com --k3s-channel v1.25 --cluster --k3s-extra-args "--node-ip=$(tailscale ip -4 rock64-1.hominions.tailnet.samcday.com) --flannel-backend=none"`
 * `sops -d home-cluster/secrets/flux-system/age-key.yaml | kubectl apply -f-`
 * `helm install flux fluxcd-community/flux2 --values <(yq -y .spec.values < home-cluster/flux-system/helm-release.yaml) -n flux-system --create-namespace`
