#!/usr/bin/env bash
# if the demo is running locally, setup things differently to AWS
USER=demo

# allow demo user to sudo without password
echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers

# re-enable ssh password login
rm /etc/ssh/sshd_config.d/disable_password_auth.conf
