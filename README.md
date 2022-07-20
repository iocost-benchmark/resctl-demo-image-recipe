# resctl-demo-image-recipe
The recipes will build the Debian-based image for the resctl-demo. The following
documentation explains how to build the images, the documentation to deploy
prebuilt images to a disk is contained in the [deployment instructions](DEPLOY.md).


## Run resctl-demo image on a local machine
See the [deployment instructions](DEPLOY.md) to download the latest images built in CI.


## Run resctl-demo image on AWS EC2 cloud machine
See the document [launch AWS EC2 instance](docs/aws-ec2-create-instance/README.md)
to launch an AWS instance.


## New version of resctl-demo released
The image pipeline builds the latest published version on crates.io, so the image
recipes always track the latest released version of resctl-demo.


## GitHub image build
To build a new image on GitHub, maintainers of the repository can:
- go to https://github.com/iocost-benchmark/resctl-demo-image-recipe
- click the `Actions` tab
- under `Workflows` click `Build resctl-demo images`
- press `Run workflow`, choose the `main` branch then press `Run workflow` again
- choose the resctl-demo source (by default it uses the latest crates.io tag, but you can also choose git HEAD)
- once the workflow has completed (about an hour) you can follow the instructions in DEPLOY.md to download the new images.


# General image information

## Root pivot
Some virtual machine hosts have SSD drives which cannot install operating systems to.
If running on AWS EC2 or the kernel cmdline parameter `resctldemo.forcepivot` is present, if there is a second
disk attached to the machine, a systemd service will attempt to copy the rootfs to this
second disk and attempt to boot from there.

To test the root pivot service, use `start-qemu-pivot.sh` which adds a second disk to the virtual machine.
The root pivot service will only run if the bootloader is modified to add `resctldemo.forcepivot` to the kernel cmdline parameters.


## CI pipeline

All branches which are pushed to GitHub run the CI pipeline (but does not upload
the images to AWS) to make sure any merge requests have a "dummy run" through the
build process.

The pipeline uses `debos` to bootstrap a customised Debian system from the
recipe located in the file `resctl-demo-ospack.yaml`. The result of this recipe
is a packed tarball of the root filesystem also known as an ospack.

After the ospack is created, the pipeline uses `debos` to create, partition and
format a disk image from the recipe `resctl-demo-image.yaml`. The ospack is
extracted into the disk image and other parameters like the Kernel cmdline are
set and the bootloader installed.

For pipelines running on the default branch, the compressed images are uploaded
to the workflow as artifacts. See the [deployment instructions](DEPLOY.md) for how
to download and flash the built images.

For pipelines running on the the default branch, the built image is uploaded
to AWS and converted to an Amazon Machine Image using the script `aws-ec2/upload-image-aws-ec2.py`.
The CI environment sets some environment variables: `EC2_ACCESS_ID`, `EC2_SECRET_KEY`,
`EC2_REGION`, `EC2_BUCKET`. These can be modified by contributors to the repository.
See the documentation included inside the the script to setup the AWS account for
images to be uploaded to.

After the pipeline has ran, under Amazon AWS interface, go to `Services > EC2` then
in the menu on the LHS, select `Images > AMIs`. The new image should be visible but
private and this will need to manually be modified to public. This is because
some QA testing may be required before allowing the public to access the image.
Click on the AMI, select the `Permissions` tab and press `Edit`. The image can be
set to `Public` using the radio button then pressing save. Do double-check by
refreshing the list.


## Image changes/updates

To change the image recipe (e.g adding an existing Debian package to the image)
please create a branch in the format `wip/<username>/<short_description>` and open
a Merge Request on this repository with a short commit description. Make sure to
set the `Assignee` to the person who should review the change. After the Merge
Request is merged to the default branch, the pipeline will run again and upload
the artifacts to AWS. To build and test an image locally, see the instructions
under the heading `Local Build instructions`.


# Local Build instructions

## System Requirements

Debian system with [debos](https://github.com/go-debos/debos) installed.

There are some options to build the images, see the detail below.

### Option 1: Debian Virtual Machine

This option is best suited for users running non-Linux operating systems.

To create a Debian virtual machine using VirtualBox, see the [following tutorial](https://getlabsdone.com/how-to-install-debian-11-on-virtualbox-step-by-step-guide/).

Be sure to give it a high amount of RAM (>4096MB), disk space (>128GB) and at
least two CPUs.

After creating the VM, enable [nested virtualization](https://ostechnix.com/how-to-enable-nested-virtualization-in-virtualbox/).

Install `debos` (and other useful tools) using apt:

    $ sudo apt update
    $ sudo apt install --yes debos git


Verify that Kernel Virtualisation is available on your machine:

    $ ls -la /dev/kvm
    crw-rw----+ 1 root kvm 10, 232 Apr  7 08:40 /dev/kvm


You may need to add the user to the `kvm` group:

    $ sudo usermod -a -G kvm $USER


After logging out and logging back in, you are ready to build the images:

    $ mkdir out
    $ debos --artifactdir=out --scratchsize=16G resctl-demo-ospack.yaml
    $ debos --artifactdir=out resctl-demo-image-legacyboot.yaml
    $ debos --artifactdir=out resctl-demo-image-efiboot.yaml
    $ debos --artifactdir=out resctl-demo-flasher-efiboot.yaml


### Option 2: Docker Container

This option is best suited for users already running a Linux distribution.

The requirement is docker installed on your machine and the user to be in the
`kvm` group:

```
$ sudo usermod -a -G kvm $USER
```

To use the Docker image, run the following helper scripts to generate the flavour
of images:

```
$ ./build-resctl-demo-images.sh
$ ./build-resctl-demo-meta-images.sh
```

### Upload AWS Legacy Boot image to AWS EC2

Since AWS cannot boot EFI images, a legacy boot image must be created.

Some environment variables need to be set to your EC2 secrets:

    EC2_ACCESS_ID, EC2_SECRET_KEY, EC2_REGION, EC2_BUCKET


    $ cd out
    $ python3 ../aws-ec2/upload-image-aws-ec2.py --ami-name="resctl-demo" --ami-description="resctl-demo" --image-file="resctl-demo-image.vmdk"


### Build resctl-demo meta variant images

The meta variant contains some additional options for specific vendor hardware.

    $ mkdir out
    $ debos --artifactdir=out -t variant:resctl-demo-meta --scratchsize=16G resctl-demo-ospack.yaml
    $ debos --artifactdir=out -t variant:resctl-demo-meta resctl-demo-image-efiboot.yaml
    $ debos --artifactdir=out -t variant:resctl-demo-meta resctl-demo-flasher-efiboot.yaml


### Customising resctl-demo meta variant

Grep the code using `git grep` for the following terms to see how the meta variant
is different:

- `git grep variant`
- `git grep resctl-demo-meta`


### Choose resctl-demo source

For the ospack, append `-t "resctl_demo_src:git HEAD"` to install the latest
version of resctl-demo from the Git repository.
