# resctl-demo-image-recipe
The recipes will build the Debian-based image for the resctl-demo.


# Requirements
Debian system with debos and qemu installed.


# Build ospack

Place binary packages for `resctl-demo` and `resctl-demo-linux` under the `debs/` directory.
See the `.gitlab-ci.yml` for further instructions.

    $ mkdir out && cd out
    $ debos --scratchsize=16G ../resctl-demo-ospack.yaml


# Build image & run under QEmu for local testing

    $ cd out
    $ debos --scratchsize=16G -t imagesize:60GB ../resctl-demo-image.yaml
    $ ../start-qemu.sh


# Build image & upload to AWS EC2

Some environment variables need to be set to your EC2 secrets:

    EC2_ACCESS_ID, EC2_SECRET_KEY, EC2_REGION, EC2_BUCKET


    $ cd out
    $ debos --scratchsize=16G ../resctl-demo-image.yaml
    $ python3 ../upload-image-aws-ec2.py --ami-name="resctl-demo" --ami-description="resctl-demo" --image-file="resctl-demo-image.vmdk"


# Root pivot
Some virtual machine hosts have SSD drives which cannot install operating systems to.
If running on AWS EC2 or the kernel cmdline parameter `resctldemo.forcepivot` is present, if there is a second
disk attached to the machine, a systemd service will attempt to copy the rootfs to this
second disk and attempt to boot from there.

To test the root pivot service, use `start-qemu-pivot.sh` which adds a second disk to the virtual machine.
The root pivot service will only run if the bootloader is modified to add `resctldemo.forcepivot` to the kernel cmdline parameters.


