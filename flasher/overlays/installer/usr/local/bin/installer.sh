#!/bin/bash

# get version from /etc/os-release
source /etc/os-release

# show choice dialog - loop until user confirms
while : ; do
  # wait for device nodes to be created
  udevadm settle

  # find the boot device
  FLASHER_STORAGE_MNT="/mnt/flasher-storage"
  FLASHER_STORAGE_DEV=$(findmnt -n -o SOURCE ${FLASHER_STORAGE_MNT})
  FLASHER_DEV="/dev/$(lsblk -n -o PKNAME ${FLASHER_STORAGE_DEV})"

  # create a list of potential target devices
  declare -a CHOICES
  CHOICES=()
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
echo "version: $IMAGE_VERSION"
echo "-----------"
echo ""
echo "Installing resctl-demo to ${CHOICE}; do not turn your computer off."
echo "You will be prompted to restart your computer after installation."
echo ""

#Remove existing MBR
dd if=/dev/zero of=${CHOICE} bs=512 count=1

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
sync

echo "Finished copying image to target."
echo ""
echo "Start post install update to image."

# Wait until target device partitions information is ready.
BOOTFS_PART=
WAIT_COUNTER=10 # randomly chosen
while (( WAIT_COUNTER > 0 )); do
  # sync partitions information
  blockdev --rereadpt  "${CHOICE}"
  # Try some more command to make host fully aware of target partitions.
  partprobe "${CHOICE}"
  udevadm settle

  BOOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "1p")
  if [ -z "${BOOTFS_PART}" ]; then
    sleep 2
    (( WAIT_COUNTER-- ))
  else
    break;
  fi
done

if [ -z "${BOOTFS_PART}" ]; then
  echo "No boot partition found on target device: ${CHOICE}"
  echo "> Listing parition information:"

  # Generate debugging info.
  FLASHER_STORAGE_RESULTS=/mnt/results
  mkdir -p ${FLASHER_STORAGE_RESULTS}
  mount PARTLABEL=results ${FLASHER_STORAGE_RESULTS}
  sfdisk -d ${CHOICE}
  # dump parititon table sector(i.e first) for debugging purpose.
  hd ${CHOICE} -n 512KB -s 0x0 > ${FLASHER_STORAGE_RESULTS}/parition_dump
  # dump dmesg log.
  dmesg > ${FLASHER_STORAGE_RESULTS}/dmesg_log
  bash
fi

ROOTFS_PART_NO=2
ROOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "${ROOTFS_PART_NO}p")

if [ -z "${ROOTFS_PART}" ]; then
  echo "No rootfs partition found on target device: ${CHOICE}"
  bash
fi

# Regenerate btrfs fsid
echo "Regenerating rootfs Filesystem UUID"
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
mount -v ${ROOTFS_PART} ${ROOTFS_MNT}
MOUNT_EXITCODE=$?
# check if mount failed
if [ ${MOUNT_EXITCODE} != 0 ] ; then
  echo ""
  echo "mount ${ROOTFS_PART} ${ROOTFS_MNT} Operation failed."
  bash
fi

# Mount boot
BOOTFS_MNT="${ROOTFS_MNT}/boot/efi"
mkdir -p ${BOOTFS_MNT}
mount -v ${BOOTFS_PART} ${BOOTFS_MNT}
MOUNT_EXITCODE=$?
# check if mount failed
if [ ${MOUNT_EXITCODE} != 0 ] ; then
  echo ""
  echo "mount ${BOOTFS_PART} ${BOOTFS_MNT} Operation failed."
  bash
fi

# Update fsid in systemd-boot configuration
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $BOOTFS_MNT/loader/entries/*.conf

# Update fsid in /etc/fstab
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $ROOTFS_MNT/etc/fstab

# Fix /etc/kernel/cmdline
sed -i "s/$ROOTFS_BLKID_OLD/$ROOTFS_BLKID_NEW/g" $ROOTFS_MNT/etc/kernel/cmdline

# Install lockfile inside rootfs to disable pivot on first boot
touch ${ROOTFS_MNT}/etc/resctl-demo/PIVOT_COMPLETE

sync

# complete
echo "Installation complete."

## Prompt user to either boot on installed image or shutdown

declare -a CHOICES
CHOICES=()
CHOICES+=("pivot" "Boot to installed image")
CHOICES+=("shutdown" "Shutdown the system")

# show the dialog
POST_CHOICE=$(dialog \
  --clear \
  --backtitle "Installation complete" \
  --title "Boot to installed image or shutdown" \
  --menu "" \
  0 0 \
  10 \
  "${CHOICES[@]}" \
  2>&1 >/dev/tty)

pivot_kernel=
pivot_initrd=
pivot_cmdline=

if [[ ${POST_CHOICE} == "pivot" ]]; then
  # Debugging
  echo "Installed boot device: $BOOTFS_PART"
  echo "Installed root device: $ROOTFS_PART"

 while read -r key value; do
    if [[ "$key" = "linux" ]]; then
      pivot_kernel="${BOOTFS_MNT}${value}";
    elif [[ "$key" = "initrd" ]]; then
      pivot_initrd="${BOOTFS_MNT}${value}";
    elif [[ "$key" = "options" ]]; then
      pivot_cmdline="$value";
    fi
  done <<< $(cat ${BOOTFS_MNT}/loader/entries/*.conf)

  echo "Boot into installed image............"

  echo "- version: $IMAGE_VERSION"
  echo "- kexec with kernel:$pivot_kernel initrd:$pivot_initrd cmdline:$pivot_cmdline"

  kexec  -l "${pivot_kernel}" --initrd="${pivot_initrd}" --command-line="${pivot_cmdline}"
  if [ $? -eq 0 ]; then
    kexec -e
  else
    echo "Failed to kexec..."
    bash
  fi

elif [[ ${POST_CHOICE} == "shutdown" ]]; then
    umount ${BOOTFS_PART}
    umount ${ROOTFS_PART}
    shutdown -r now
fi

shutdown -r now
