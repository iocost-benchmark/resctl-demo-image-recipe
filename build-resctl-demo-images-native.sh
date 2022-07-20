#!/bin/sh
set -e

mkdir -p out
debos --artifactdir=out --scratchsize=16G resctl-demo-ospack.yaml
debos --artifactdir=out resctl-demo-image-efiboot.yaml
debos --artifactdir=out resctl-demo-flasher-efiboot.yaml
