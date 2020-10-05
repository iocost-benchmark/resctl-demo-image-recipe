#!/bin/sh

CMDLINE=$1

# Install GRUB2 for legacy boot
apt-get install --yes grub-pc

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
