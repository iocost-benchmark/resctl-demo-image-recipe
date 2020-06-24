#!/usr/bin/env bash
USER=demo
PASS=${USER}

adduser --gecos ${USER} --disabled-password --shell /bin/bash ${USER}
adduser ${USER} sudo
echo "${USER}:${PASS}" | chpasswd

# add /usr/sbin to path
cat <<EOF >> /home/${USER}/.profile

# resctl-demo
PATH="/usr/sbin:$PATH"
EOF
