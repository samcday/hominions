#!/bin/bash

kubectl apply -f kube-flannel/kube-flannel.yaml
helm install flux fluxcd-community/flux2 --values flux-values.yaml -n flux-system --create-namespace
sops -d secrets/flux-system/age-key.yaml | kubectl apply -f-
