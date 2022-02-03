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
if [ ${CHOICE_EXITCODE} = 1 ] || [ "${CHOICE}" = "cancel" ] ; then
  echo "Operation cancelled by user."
  read -p "Press return to shutdown your computer..."
  shutdown -h now
fi


dialog --clear \
  --backtitle "resctl-demo installer" \
  --title "Choose disk to install resctl-demo" \
  --defaultno \
  --yesno "You have chosen to install resctl-demo to $CHOICE\n\nWARNING: the disk will be overwritten! Choose no to cleanly exit." \
  20 0
CHOICE_EXITCODE=$?

if [ ${CHOICE_EXITCODE} != 0 ] ; then
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

bmaptool \
  copy \
  --nobmap \
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
partprobe "${CHOICE}"

# Expand rootfs partition table
ROOTFS_PART_NO=2
ROOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "${ROOTFS_PART_NO}p")
echo "Expanding ${ROOTFS_PART}"
parted -s ${CHOICE} resizepart ${ROOTFS_PART_NO} 100%

# Reload partition table
partprobe "${CHOICE}"

# Regenerate btrfs fsid
ROOTFS_BLKID_OLD=$(blkid -s UUID -o value ${ROOTFS_PART})
btrfstune -m ${ROOTFS_PART}

# Reload partition table
partprobe "${CHOICE}"

# Get the new fsid
ROOTFS_BLKID_NEW=$(blkid -s UUID -o value ${ROOTFS_PART})

# Mount rootfs
ROOTFS_MNT="/mnt/rootfs"
mkdir -p ${ROOTFS_MNT}
mount ${ROOTFS_PART} ${ROOTFS_MNT}

# Update fsid in grub configuration
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" "$ROOTFS_MNT/boot/grub/grub.cfg"

# Update fsid in /etc/default/grub
sed -i "s/LABEL=system/UUID=$ROOTFS_BLKID_NEW/g" "$ROOTFS_MNT/etc/default/grub"

# Update fsid in /etc/fstab
sed -i "s/LABEL=system/UUID=$ROOTFS_BLKID_NEW/g" "$ROOTFS_MNT/etc/fstab"

# Fix /etc/kernel/cmdline
sed -i "s/UUID=$ROOTFS_BLKID_OLD/UUID=$ROOTFS_BLKID_NEW/g" "$ROOTFS_MNT/etc/kernel/cmdline"
sed -i "s/LABEL=system//g" "$ROOTFS_MNT/etc/kernel/cmdline"

# Expand rootfs
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
