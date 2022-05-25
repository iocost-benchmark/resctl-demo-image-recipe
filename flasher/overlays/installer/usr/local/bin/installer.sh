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

# add extra choices
CHOICES+=("shell" "Drop to a shell")
CHOICES+=("quit" "Quit (Shutdown Machine without modifications)")

# show choice dialog - loop until user confirms
while : ; do
  CHOICE=$(dialog \
    --clear \
    --backtitle "resctl-demo installer" \
    --title "Choose disk to install resctl-demo" \
    --menu "WARNING: the disk will be overwritten! Choose Quit to cleanly exit." \
    0 0 \
    10 \
    "${CHOICES[@]}" \
    2>&1 >/dev/tty)

  # if the user cancels by mistake, show the dialog again
  CHOICE_EXITCODE=$?
  if [ $CHOICE_EXITCODE = 1 ] ; then
    continue
  fi

  if [ "${CHOICE}" = "shell" ] ; then
    bash
    continue
  fi

  # if the user quits, then really shutdown
  if [ "${CHOICE}" = "quit" ] ; then
    echo "Operation cancelled by user."
    sleep 5
    shutdown -h now
  fi

  # more information about the disk choice
  CHOICE_INFO=$(lsblk -n -d -o MODEL,SIZE,SERIAL $CHOICE)

  # confirm
  dialog --clear \
    --backtitle "resctl-demo installer" \
    --title "Choose disk to install resctl-demo" \
    --defaultno \
    --yesno "You have chosen to install resctl-demo to $CHOICE ($CHOICE_INFO)\nWARNING: the disk will be overwritten! Choose no to go back to the main menu." \
    20 0

  # if the user cancels by mistake, show the dialog again. otherwise break the loop
  # and continue installing
  CHOICE_EXITCODE=$?
  if [ $CHOICE_EXITCODE = 0 ] ; then
    break
  fi
done

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
sleep 10
echo fix | parted ---pretend-input-tty ${CHOICE} print
sync
sleep 10

ROOTFS_PART_NO=2
BOOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "1p")
ROOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "${ROOTFS_PART_NO}p")

# Expand rootfs partition table
echo "Expanding root partition ${ROOTFS_PART}"
parted -s ${CHOICE} resizepart ${ROOTFS_PART_NO} 100%
sync
sleep 10

# Regenerate btrfs fsid
ROOTFS_BLKID_OLD=$(blkid -s UUID -o value ${ROOTFS_PART})
echo "Old blkid $ROOTFS_BLKID_OLD"
btrfstune -m ${ROOTFS_PART}
sync
sleep 10

# Get the new fsid
ROOTFS_BLKID_NEW=$(blkid -s UUID -o value ${ROOTFS_PART})
echo "New blkid $ROOTFS_BLKID_NEW"

# Mount rootfs
ROOTFS_MNT="/mnt/rootfs"
mkdir -p ${ROOTFS_MNT}
mount ${ROOTFS_PART} ${ROOTFS_MNT}

# Expand rootfs
btrfs filesystem resize max ${ROOTFS_MNT}
sync
sleep 10

# Mount boot
BOOTFS_MNT="${ROOTFS_MNT}/boot/efi"
mkdir -p ${BOOTFS_MNT}
mount ${BOOTFS_PART} ${BOOTFS_MNT}

# Update fsid in systemd-boot configuration
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $BOOTFS_MNT/loader/entries/*.conf

# Update fsid in /etc/fstab
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $ROOTFS_MNT/etc/fstab

# Fix /etc/kernel/cmdline
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $ROOTFS_MNT/etc/kernel/cmdline

# Install lockfile inside rootfs to disable pivot on first boot
touch ${ROOTFS_MNT}/etc/resctl-demo/PIVOT_COMPLETE

# Unmount rootfs
umount ${BOOTFS_PART}
umount ${ROOTFS_PART}
sync

# complete
echo ""
echo ""
echo "Installation complete."
read -p "Press return to restart computer..."
shutdown -r now
