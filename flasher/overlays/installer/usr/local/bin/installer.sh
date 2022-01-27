#!/bin/bash

# find the boot device
FLASHER_STORAGE_MNT="/mnt/flasher-storage"
FLASHER_STORAGE_DEV=$(findmnt -n -o SOURCE ${FLASHER_STORAGE_MNT})
FLASHER_DEV="/dev/$(lsblk -n -o PKNAME ${FLASHER_STORAGE_DEV})"

# create a list of potential target devices
declare -a CHOICES
for DEV_PATH in $(lsblk -n -d -o PATH); do

  # check this device is not the boot device
  [ "${DEV_PATH}" == "${FLASHER_DEV}" ] && continue

  # add drive to the choice dialog
  DEV_INFO=$(lsblk -n -d -o MODEL,SIZE,SERIAL ${DEV_PATH} | tr -s ' ')
  CHOICES+=("${DEV_PATH}" "${DEV_INFO}")
done

# add cancel choice
CHOICES+=("cancel" "Cancel")

# show choice dialog
CHOICE=$(dialog \
  --clear \
  --backtitle "resctl-demo installer" \
  --title "Choose disk to install resctl-demo" \
  --menu "WARNING: the disk will be overwritten! Choose cancel to cleanly exit." \
  0 0 \
  10 \
  "${CHOICES[@]}" \
  2>&1 >/dev/tty)
CHOICE_EXITCODE=$?
clear

# quit
if [ ${CHOICE_EXITCODE} == 1 ] || [ "${CHOICE}" == "cancel" ] ; then
  echo "Operation cancelled by user."
  read -p "Press return to shutdown your computer..."
  shutdown -h now
fi

# install the image
echo "-----------"
echo "resctl-demo"
echo "-----------"
echo ""
echo "Installing resctl-demo to ${CHOICE}; do not turn your computer off."
echo "You will be prompted to restart your computer after installation."
echo ""

# Discard used blocks on EMMC
blkdiscard -f ${CHOICE}

bmaptool \
  copy \
  ${FLASHER_STORAGE_MNT}/resctl-demo-image.img.gz \
  ${CHOICE}
BMAP_EXITCODE=$?

# check if install failed
if [ ${BMAP_EXITCODE} != 0 ] ; then
  echo ""
  echo ""
  echo "Operation failed. See error message above."
  read -p "Press return to shutdown your computer..."
  shutdown -h now
fi

# Fix GPT to take the full size
echo fix | parted ---pretend-input-tty ${CHOICE} print

# Reload partition table
udevadm trigger --settle "${CHOICE}"

# Expand rootfs partition table
ROOTFS_PART_NO=2
ROOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "${ROOTFS_PART_NO}p")
echo "Expanding ${ROOTFS_PART}"
parted -s ${CHOICE} resizepart ${ROOTFS_PART_NO} 100%

# Reload partition table
udevadm trigger --settle "${CHOICE}"

# Regenerate btrfs fsid
btrfstune -m ${ROOTFS_PART}

# Expand rootfs
ROOTFS_MNT="/mnt/rootfs"
mkdir -p ${ROOTFS_MNT}
mount ${ROOTFS_PART} ${ROOTFS_MNT}
btrfs filesystem resize max ${ROOTFS_MNT}

# Install lockfile inside rootfs to disable pivot on first boot
touch ${ROOTFS_MNT}/etc/resctl-demo/PIVOT_COMPLETE

# Unmount rootfs
umount ${ROOTFS_PART}
sync

# complete
echo ""
echo ""
echo "Installation complete."
read -p "Press return to restart computer..."
shutdown -r now
