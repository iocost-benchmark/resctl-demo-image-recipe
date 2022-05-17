# resctl-demo images

To use resctl-demo locally, first you need to prepare a USB stick with the
flasher image. Then, boot into the flasher image to flash the resctl-demo
environment to the SSD you wish to test.

Finally, you may boot the machine to the resctl-demo environment flashed onto
the SSD under test.


## Prepare USB stick
** WARNING: Booting this image and following the prompts may remove all of your personal data. **
** Be sure to replace `{YOUR_DEVICE}` with the correct node for your USB stick **

Copy the flasher image to a USB stick with a size at least 16GB using one of the
following methods:


### bmaptool

Collabora suggest to use `bmaptool` to copy the image, since the data is checksummed
at all stages, so you can be sure the image is written correctly.

It is available for most distributions under the package name `bmap-tools` and
is usually contained in the default repositories (or in AUR for Arch):

  - [Debian](https://packages.debian.org/stable/bmap-tools)
  - [Fedora](https://src.fedoraproject.org/rpms/bmap-tools)
  - [Arch AUR](https://aur.archlinux.org/packages/bmap-tools)


Flash the image directly to the device (bmaptool handles decompression, checksumming
and only writes used blocks to the drive: it is FAST), for the default images:

    $ wget https://nightly.link/iocost-benchmark/resctl-demo-image-recipe/workflows/ci.yaml/main/resctl-demo-flasher-efiboot.zip
    $ unzip resctl-demo-flasher-efiboot.zip
    $ sudo bmaptool copy resctl-demo-flasher-efiboot.img.gz /dev/{YOUR_DEVICE}

or, for the meta variant:

    $ wget https://nightly.link/iocost-benchmark/resctl-demo-image-recipe/workflows/ci.yaml/main/resctl-demo-meta-flasher-efiboot.zip
    $ unzip resctl-demo-meta-flasher-efiboot.zip
    $ sudo bmaptool copy resctl-demo-meta-flasher-efiboot.img.gz /dev/{YOUR_DEVICE}


### Etcher

Etcher is available for multiple operating systems, see the [etcher website](https://www.balena.io/etcher/)
for more information.


### dd

Using `dd` is more complicated than `bmaptool`, and takes much more time since
it requires manually checksumming the images and writes all data to the disk.

If any of the following commands fail, it is likely your final USB image is corrupt.

    $ wget https://nightly.link/iocost-benchmark/resctl-demo-image-recipe/workflows/ci.yaml/main/resctl-demo-flasher-efiboot.zip
    $ unzip resctl-demo-flasher-efiboot.zip
    $ sha256sum --check resctl-demo-flasher-efiboot.img.gz.sha256
    $ gunzip resctl-demo-flasher-efiboot.img.gz
    $ sudo dd if=resctl-demo-flasher-efiboot.img of=/dev/{YOUR_DEVICE} bs=8M oflag=dsync status=progress
    $ sudo cmp -n `stat -c '%s' resctl-demo-flasher-efiboot.img` resctl-demo-flasher-efiboot.img /dev/{YOUR_DEVICE}

or, for the meta variant:

    $ wget https://nightly.link/iocost-benchmark/resctl-demo-image-recipe/workflows/ci.yaml/main/resctl-demo-meta-flasher-efiboot.zip
    $ unzip resctl-demo-meta-flasher-efiboot.zip
    $ sha256sum --check resctl-demo-meta-flasher-efiboot.img.gz.sha256
    $ gunzip resctl-demo-meta-flasher-efiboot.img.gz
    $ sudo dd if=resctl-demo-meta-flasher-efiboot.img of=/dev/{YOUR_DEVICE} bs=8M oflag=dsync status=progress
    $ sudo cmp -n `stat -c '%s' resctl-demo-meta-flasher-efiboot.img` resctl-demo-meta-flasher-efiboot.img /dev/{YOUR_DEVICE}


## Booting

Boot the USB stick using EFI, a screen will ask which drive to install the OS to.

If the flasher fails, you may use `Ctrl+Alt+F2` to get to a console, with the
credentials being `root:root`.

Once complete, you may remove the USB stick and reboot into the resctl-demo
environment and follow the on-screen instructions.
