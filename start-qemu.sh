#!/usr/bin/env bash

IMAGE=resctl-demo-image.img

qemu-system-x86_64 \
  -machine type=q35,accel=kvm \
  -cpu host \
  -smp cpus=1 \
  -m 2048M \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=${IMAGE},if=none,format=raw,discard=unmap,aio=native,cache=none,id=someid -device scsi-hd,drive=someid,bus=scsi0.0 \
  -vga std \
  -device e1000,netdev=n1 \
  -netdev user,id=n1,hostfwd=tcp::2222-:22
