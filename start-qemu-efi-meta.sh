#!/usr/bin/env bash

IMAGE=resctl-demo-meta-image-efiboot.img

qemu-system-x86_64 \
  -machine type=q35,accel=kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cpu host \
  -smp cpus=1 \
  -m 2048M \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=${IMAGE},if=none,format=raw,discard=unmap,aio=native,cache=none,id=someid -device scsi-hd,drive=someid,bus=scsi0.0 \
  -vga qxl \
  -chardev stdio,mux=on,id=char0 \
  -mon chardev=char0,mode=readline \
  -serial chardev:char0 \
  -serial chardev:char0 \
  -device e1000,netdev=n1 \
  -netdev user,id=n1,hostfwd=tcp::2222-:22
