#!/bin/sh

set -e

GIT_TAG="v0.3.0"

echo "Installing OOMD from source"
cd /opt

# install build deps
apt-get install --yes git meson build-essential libjsoncpp-dev libsystemd-dev libgtest-dev libgmock-dev

# setup git configuration
git config --global advice.detachedHead false
git config --global user.email "ci@collabora.com"
git config --global user.name "Collabora CI"

# clone source
git clone https://github.com/facebookincubator/oomd.git
cd oomd
git checkout ${GIT_TAG}

# pick relevent commits
git cherry-pick 64e46deb6ab01900944d618a26c00a70ee0dba5e

# build
meson build && ninja -C build

# install
cd build && ninja install

# disable oomd service
systemctl mask oomd.service

# cleanup
cd / && rm -rf /opt/oomd
