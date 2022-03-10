#!/bin/bash

# the flasher image is mounted as $IMAGEMNTDIR; the container is mounted as $ROOTDIR
# the flasher has created a debian container; this script copies the useful
# parts into the flasher image and installs a bootloader

set -e
set -u

VARIANT=$1
INSTALLER_TTY="/dev/tty1"
VARIANT_OPTIONS="console=ttyS0,115200n8 console=tty0"
if [ "$VARIANT" = "resctl-demo-meta" ]; then
  INSTALLER_TTY="/dev/ttyS1"
  VARIANT_OPTIONS="console=ttyS1,57600n8"
fi

cd ${IMAGEMNTDIR}

# Update installer TTY
sed -i "s|{INSTALLER_TTY}|$INSTALLER_TTY|" ${ROOTDIR}/etc/systemd/system/installer.service

# Install systemd-boot
mkdir -p EFI/BOOT
cp ${ROOTDIR}/usr/lib/systemd/boot/efi/systemd-bootx64.efi EFI/BOOT/BOOTX64.EFI

mkdir -p EFI/systemd
cp ${ROOTDIR}/usr/lib/systemd/boot/efi/systemd-bootx64.efi EFI/systemd/systemd-bootx64.efi

mkdir -p loader/entries

cat << EOF > loader/loader.conf
timeout 10
default $VARIANT flasher
EOF

cat << EOF > loader/entries/flasher.conf
title $VARIANT flasher
linux /linux
initrd /initramfs.cpio.gz
options root=/dev/ram0 $VARIANT_OPTIONS systemd.unit=installer.target systemd.show_status quiet
EOF

# Copy kernel
cp ${ROOTDIR}/boot/vmlinuz* linux

# Create initramfs from container contents
cd ${ROOTDIR}
rm -rf boot
find -H | cpio -H newc -o | pigz -c - > ${IMAGEMNTDIR}/initramfs.cpio.gz
