FROM godebos/debos
ARG DEBIAN_FRONTEND=noninteractive

RUN /usr/bin/apt-get update && \
    /usr/bin/apt-get -y --no-install-recommends install \
      curl \
      efibootmgr \
      grub-efi-amd64 \
      openssh-client \
      python3-pip \
      rsync \
      qemu-utils

# python3-libcloud in debian/buster is outdated and does not work
# install from pip using a freezed file to assume some continuity
COPY requirements.txt /tmp/
RUN /usr/bin/pip3 install --requirement /tmp/requirements.txt
