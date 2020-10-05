#!/usr/bin/env bash

FLASHER_IMG="resctl-demo-flasher-efiboot.img"
ROOT_IMG="resctl-demo-flasher-efiboot-testroot.img"

# create a disk to install to
qemu-img create -f qcow2 ${ROOT_IMG} 100G

qemu-system-x86_64 \
  -machine type=q35,accel=kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cpu host \
  -smp cpus=1 \
  -m 2048M \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=${FLASHER_IMG},if=none,format=raw,id=flasher -device scsi-hd,drive=flasher,bus=scsi0.0 \
  -device virtio-scsi-pci,id=scsi1 \
  -drive file=${ROOT_IMG},if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=testroot -device scsi-hd,drive=testroot,bus=scsi1.0 \
  -boot menu=on \
  -vga qxl \
  -serial stdio \
  -device e1000,netdev=n1 \
  -netdev user,id=n1,hostfwd=tcp::2222-:22
