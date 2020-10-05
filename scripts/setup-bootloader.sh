#!/bin/sh

GRUB_TARGET=$1
CMDLINE=$2


case ${GRUB_TARGET} in
  i386-pc)
    # Install GRUB2 for legacy boot
    apt-get install --yes --no-install-recommends grub-pc
    grub-install --target="${GRUB_TARGET}" "${IMAGE}"
    ;;

  x86_64-efi)
    # Install GRUB2 for efi boot
    apt-get install --yes --no-install-recommends grub-efi-amd64 efibootmgr
    grub-install --target="${GRUB_TARGET}" "${IMAGE}"

    # Use GRUB2 as default bootloader
    mkdir -p /boot/efi/EFI/boot
    cp /boot/efi/EFI/debian/grubx64.efi /boot/efi/EFI/boot/bootx64.efi
    ;;

  *)
    echo "Error: ${GRUB_TARGET} not supported"
    exit 1
    ;;
esac

# Do not include quiet in cmdline
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub

# Set GRUB2 cmdline
sed -i "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${CMDLINE}\"/g" /etc/default/grub

# Do not include root=UUID in cmdline
sed -i 's/^#GRUB_DISABLE_LINUX_UUID/GRUB_DISABLE_LINUX_UUID/g' /etc/default/grub

# Really make sure root= is not included in cmdline
# (grub is yet again trying to be helpful)
sed -i 's/root=${linux_root_device_thisversion} ro //g' /etc/grub.d/10_linux

# Create the menu file
update-grub
