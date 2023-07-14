#!/bin/bash
set -uexo pipefail

IMAGE="$(ls fedora-coreos-*.qcow2)"

if [[ -z "${IMAGE}" ]]; then
  podman run --rm -v `pwd`:/data -w /data quay.io/coreos/coreos-installer:release download -p qemu -f qcow2.xz --decompress
  IMAGE="$(ls fedora-coreos-*.qcow2)"
fi

./generate-ignition.sh

IGNITION_CONFIG="`pwd`/config.ign"
VM_NAME="librem-test"
VCPUS="2"
RAM_MB="2048"
STREAM="stable"
DISK_GB="10"

IGNITION_DEVICE_ARG=(--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG}")

if sudo virsh --connect="qemu:///system" desc ${VM_NAME}; then
  sudo virsh --connect="qemu:///system" shutdown "${VM_NAME}"
  sudo virsh --connect="qemu:///system" destroy "${VM_NAME}"
  sudo virsh --connect="qemu:///system" undefine "${VM_NAME}"
fi

sudo virt-install --connect="qemu:///system" --name="${VM_NAME}" --vcpus="${VCPUS}" --memory="${RAM_MB}" \
        --os-variant="fedora-coreos-$STREAM" --import --graphics=none \
        --disk="size=${DISK_GB},backing_store=`pwd`/${IMAGE}" \
        --network bridge=virbr0  "${IGNITION_DEVICE_ARG[@]}"
