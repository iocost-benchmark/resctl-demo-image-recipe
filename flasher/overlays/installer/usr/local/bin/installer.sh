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

# Install the image to the target disk
echo "-----------"
echo "resctl-demo"
echo "version: $IMAGE_VERSION"
echo "-----------"
echo ""
echo "Installing resctl-demo to ${CHOICE}; do not turn your computer off."
echo "You will be prompted to restart your computer after installation."
echo ""

# Create the partition layout.
# (systemd >=254 is required; otherwise sector size is not read from device & fixed at 512)
systemd-repart \
  --dry-run=no \
  --empty=force \
  --discard=no \
  --pretty=yes \
  ${CHOICE}

# Wait for partition table to settle.
sleep 10

# Determine the full path to the newly created partitions.
BOOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "1p")
ROOTFS_PART=$(lsblk -n -o PATH | grep "${CHOICE}" | grep -Fvx "${CHOICE}" | sed -n "2p")
echo "Boot partition: $BOOTFS_PART"
echo "Root partition: $ROOTFS_PART"

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

# Extract system tarball
echo ""
echo "Installing system... please wait..."
pv ${FLASHER_STORAGE_MNT}/resctl-demo-image.tar.gz | tar -zx --directory ${ROOTFS_MNT} -f -

# Various files have been populated with the filesystem UUID generated at
# build-time. Update them to match the newly-created filesystem UUID.

# Read rootfs filesystem uuid
ROOTFS_UUID=$(blkid -s UUID -o value ${ROOTFS_PART})
ROOTFS_UUID_OLD=$(grep -oP 'UUID=\K[^\s]+' $ROOTFS_MNT/etc/fstab | head -n1)
echo "Old root filesystem UUID: $ROOTFS_UUID_OLD"
echo "Root filesystem UUID: $ROOTFS_UUID"

# Update fs uuid in systemd-boot configuration
sed -i "s/$ROOTFS_UUID_OLD/$ROOTFS_UUID/g" $BOOTFS_MNT/loader/entries/*.conf

# Update fs uuid in /etc/fstab
sed -i "s/$ROOTFS_UUID_OLD/$ROOTFS_UUID/g" $ROOTFS_MNT/etc/fstab

# Update fs uuid /etc/kernel/cmdline
sed -i "s/$ROOTFS_UUID_OLD/$ROOTFS_UUID/g" $ROOTFS_MNT/etc/kernel/cmdline

# Install lockfile inside rootfs to disable pivot on first boot
touch ${ROOTFS_MNT}/etc/resctl-demo/PIVOT_COMPLETE

echo "Installation complete."
sleep 10

## Prompt user to either pivot to installed image or shutdown

declare -a CHOICES
CHOICES=()
CHOICES+=("pivot" "Pivot to installed image")
CHOICES+=("shutdown" "Shutdown the system")

# show the dialog
POST_CHOICE=$(dialog \
  --clear \
  --backtitle "Installation complete" \
  --title "Pivot to installed image or shutdown" \
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

  echo "Pivoting into installed image............"
  echo "- version: $IMAGE_VERSION"
  echo "- kernel: $pivot_kernel"
  echo "- initrd: $pivot_initrd"
  echo "- cmdline: $pivot_cmdline"

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
