#!/bin/bash

# the flasher image is mounted as $IMAGEMNTDIR; the container is mounted as $ROOTDIR
# the flasher has created a debian container; this script copies the useful
# parts into the flasher image and installs a bootloader

set -e
set -u

# Install GRUB2 to ESP
GRUB_TARGET="x86_64-efi"
grub-install \
  --directory="${ROOTDIR}/usr/lib/grub/${GRUB_TARGET}" \
  --target="${GRUB_TARGET}" \
  --locale-directory="${ROOTDIR}/usr/share/locale" \
  --boot-directory="${IMAGEMNTDIR}/boot" \
  --efi-directory="${IMAGEMNTDIR}" \
  "${IMAGE}"

# Use GRUB2 as default bootloader
mkdir -p "${IMAGEMNTDIR}/EFI/boot"
cp "${IMAGEMNTDIR}/EFI/grub/grubx64.efi" "${IMAGEMNTDIR}/EFI/boot/bootx64.efi"

# Create basic GRUB2 menu
ROOT_UUID=$(blkid "${IMAGE}-part1" -s UUID -o value)
cat << EOF > ${IMAGEMNTDIR}/boot/grub/grub.cfg
insmod all_video
insmod gfxterm

menuentry 'Install resctl-demo' --id resctl-demo-flasher {
  search --set=root --fs-uuid ${ROOT_UUID} --hint hd0,msdos2
  linux /vmlinuz root=/dev/ram0 rootfstype=ramfs console=tty0 console=ttyS0 quiet loglevel=3 systemd.unit=installer.target
  initrd /initramfs.cpio.gz
}

menuentry 'Reboot' {
  reboot
}

menuentry 'Shutdown' {
  halt
}

default=resctl-demo-flasher
timeout=10
EOF

# Copy kernel
cp ${ROOTDIR}/boot/vmlinuz* ${IMAGEMNTDIR}/vmlinuz

# Create initramfs from container contents
cd ${ROOTDIR}
rm -rf boot
find -H | cpio -H newc -o | pigz -c - > ${IMAGEMNTDIR}/initramfs.cpio.gz
