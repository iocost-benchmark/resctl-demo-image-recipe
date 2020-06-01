# resctl-demo-image-recipe
The recipes will build the Debian-based image for the resctl-demo.


# Requirements
Debian system with debos and qemu installed.


# Build

    $ mkdir out && cd out
    $ debos --scratchsize=8G ../resctl-demo-ospack.yaml
    $ debos --scratchsize=8G ../resctl-demo-image.yaml


# Run under QEmu

    $ cd out
    $ ../start-qemu.sh
