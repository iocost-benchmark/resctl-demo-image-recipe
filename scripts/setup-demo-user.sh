#!/usr/bin/env bash
USER=demo
PASS=${USER}

adduser --gecos ${USER} --disabled-password --shell /bin/bash ${USER}
adduser ${USER} sudo
echo "${USER}:${PASS}" | chpasswd
