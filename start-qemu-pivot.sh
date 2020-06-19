#!/usr/bin/env bash

IMAGE=resctl-demo-image.img

# create a second disk to pivot to
qemu-img create -f qcow2 resctl-demo-second-disk.img 100G

qemu-system-x86_64 \
  -machine type=q35,accel=kvm \
  -cpu host \
  -smp cpus=1 \
  -m 2048M \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=${IMAGE},if=none,format=raw,discard=unmap,aio=native,cache=none,id=someid -device scsi-hd,drive=someid,bus=scsi0.0 \
  -device virtio-scsi-pci,id=scsi1 \
  -drive file=resctl-demo-second-disk.img,if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=someid2 -device scsi-hd,drive=someid2,bus=scsi1.0 \
  -vga std \
  -device e1000,netdev=n1 \
  -netdev user,id=n1,hostfwd=tcp::2222-:22
