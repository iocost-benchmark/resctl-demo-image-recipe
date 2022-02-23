# resctl-demo images

## Run resctl-demo on local machine
** WARNING: Booting this image and following the prompts may remove all of your personal data. ** 

Copy the flasher image available from [images.collabora.com](https://images.collabora.com/facebook/)
to a USB stick with a size at least 16GB:

    $ bmaptool copy https://images.collabora.com/facebook/resctl-demo-latest/resctl-demo-flasher-efiboot.img.gz /dev/sda

Or you may copy the image directly without using bmaptool:

    $ wget https://images.collabora.com/facebook/resctl-demo-latest/resctl-demo-flasher-efiboot.img.gz
    $ gunzip resctl-demo-flasher-efiboot.img.gz
    $ dd if=resctl-demo-flasher.img of=/dev/sda bs=8M status=progress


Boot the USB stick using EFI, a screen will ask which drive to install the OS to.

If the flasher fails, you may use `Ctrl+Alt+F2` to get to a console, with the
credentials being `root:root`.

Once complete, you may remove the USB stick and reboot into the resctl-demo
environment.
