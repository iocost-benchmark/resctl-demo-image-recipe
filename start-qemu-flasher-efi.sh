#!/usr/bin/env bash

FLASHER_IMG="resctl-demo-flasher-efiboot.img"
ROOT1_IMG="resctl-demo-flasher-efiboot-testroot1.img"
ROOT2_IMG="resctl-demo-flasher-efiboot-testroot2.img"
ROOT3_IMG="resctl-demo-flasher-efiboot-testroot3.img"

# create a disk to install to
qemu-img create -f qcow2 ${ROOT1_IMG} 512G
qemu-img create -f qcow2 ${ROOT2_IMG} 512G
qemu-img create -f qcow2 ${ROOT3_IMG} 512G

qemu-system-x86_64 \
  -machine type=q35,accel=kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -cpu host \
  -smp cpus=1 \
  -m 2048M \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=${FLASHER_IMG},if=none,format=raw,id=flasher -device scsi-hd,drive=flasher,bus=scsi0.0 \
  -device virtio-scsi-pci,id=scsi1 \
  -drive file=${ROOT1_IMG},if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=testroot1 -device scsi-hd,drive=testroot1,bus=scsi1.0 \
  -drive file=${ROOT2_IMG},if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=testroot2 -device nvme,drive=testroot2,serial=1234 \
  -drive file=${ROOT3_IMG},if=none,format=qcow2,discard=unmap,aio=native,cache=none,id=testroot3 -device virtio-blk,drive=testroot3,serial=4096_blk_size,logical_block_size=4096,physical_block_size=4096 \
  -boot menu=on \
  -vga qxl \
  -serial stdio \
  -device e1000,netdev=n1 \
  -netdev user,id=n1,hostfwd=tcp::2222-:22
