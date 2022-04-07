# resctl-demo-image-recipe
The recipes will build the Debian-based image for the resctl-demo. The following
documentation explains how to build the images, the documentation to deploy
prebuilt images to a disk is contained in a seperate file [DEPLOY.md](DEPLOY.md).


## Run resctl-demo on AWS EC2 cloud machine
See the document [launch AWS EC2 instance](docs/aws-ec2-create-instance/README.md)
to launch an AWS instance.


## Image downloads
The images built using the CI pipeline on the default branch can be downloaded
from [images.collabora.com](https://images.collabora.com/facebook/). These images
are also uploaded and converted to AWS using the Amazon secrets provided by the
customer.


# General image information

## Root pivot
Some virtual machine hosts have SSD drives which cannot install operating systems to.
If running on AWS EC2 or the kernel cmdline parameter `resctldemo.forcepivot` is present, if there is a second
disk attached to the machine, a systemd service will attempt to copy the rootfs to this
second disk and attempt to boot from there.

To test the root pivot service, use `start-qemu-pivot.sh` which adds a second disk to the virtual machine.
The root pivot service will only run if the bootloader is modified to add `resctldemo.forcepivot` to the kernel cmdline parameters.




# GitLab CI Build instructions

## Requirements

Before running the CI pipeline, the following repositories must be built using
their own CI pipelines:

 * [resctl-demo Application](https://gitlab.collabora.com/facebook/resctl-demo)
 * [resctl-demo Linux Kernel](https://gitlab.collabora.com/facebook/resctl-demo-linux)

For instructions of how to modify/update these repositories see the file `debian/README.md`
located under the `debian/master` branch of each of the repositories above.


## CI pipeline

All branches which are pushed to GitLab run the CI pipeline (but does not upload
the images to AWS) to make sure any merge requests have a "dummy run" through the
build process.

The pipeline first creates a customised Docker image for the build process. See
the dockerfile located under `ci-image-builder/Dockerfile`.

The CI pipeline downloads the build packages from the above repositories,
specifically the artifacts of the last pipeline which passed from the `debian/master`
branches. If the artifacts are missing, the image will fail to build. At this stage,
the pipeline also downloads the Linux kernel payload.

Next the pipeline uses `debos` to bootstrap a customised Debian system from the
recipe located in the file `resctl-demo-ospack.yaml`. The result of this recipe
is a packed tarball of the root filesystem also known as an ospack.

After the ospack is created, the pipeline uses `debos` to create, partition and
format a disk image from the recipe `resctl-demo-image.yaml`. The ospack is
extracted into the disk image and other parameters like the Kernel cmdline are
set and the bootloader installed.

For pipelines running on the default branch, the compressed images are uploaded
to the project's [image storage area](https://images.collabora.com/facebook/).

For pipelines running on the the default branch, the built image is uploaded
to AWS and converted to an Amazon Machine Image using the script `aws-ec2/upload-image-aws-ec2.py`.
The CI environment sets some environment variables: `EC2_ACCESS_ID`, `EC2_SECRET_KEY`,
`EC2_REGION`, `EC2_BUCKET`. These can be modified by Collabora on request.
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

If no changes to the image recipes are required but the image needs to be rebuilt
(e.g the Linux Kernel package was updated), please wait for the downstream CI
pipeline of the package in question to complete and then re-run the pipeline in
this repository. To do this, go to the `CI / CD` page using the navigation bar on
the left-hand side, then press the `Run Pipeline` button at the top of the page
and then pressing `Run Pipeline` again on the next page. The pipeline will now
run and the status can be monitored by going to the `CI / CD > Pipelines` page.

The created image is private; see the steps above to make the image public.


# Local Build instructions

## System Requirements

Debian system with [debos](https://github.com/go-debos/debos) installed.

There are two options, see the detail below.

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


After logging out and logging back in, you are ready to run build images!


### Option 2: Debian Docker Container

This option is best suited for users already running a Linux distribution.

To use the Debos Docker image, in the setps following when you see `debos ...` instead
pass the arguments to a docker script.

For instance, to run `debos --help`, instead run:

```
docker run \
       --rm \
       -w /recipes \
       -v $(pwd):/recipes \
       -u $(id -u):$(id -g) \
       --group-add=$(getent group kvm | cut -d : -f 3) \
       --device /dev/kvm \
       --security-opt label=disable \
       go-debos/debos \
       --help
```


### Build resctl-demo images

    $ mkdir out
    $ debos --artifactdir=out --scratchsize=16G resctl-demo-ospack.yaml
    $ debos --artifactdir=out resctl-demo-flasher-legacyboot.yaml
    $ debos --artifactdir=out resctl-demo-image-efiboot.yaml
    $ debos --artifactdir=out resctl-demo-flasher-efiboot.yaml


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
