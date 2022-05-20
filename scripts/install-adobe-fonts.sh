#!/bin/bash
set -e

# Install adobe fonts
git clone --depth=1 https://github.com/adobe-fonts/source-code-pro.git /tmp/adobe-fonts
cp /tmp/adobe-fonts/TTF/*.ttf /usr/local/share/fonts/
fc-cache -f -v /usr/local/share/fonts/
rm -rf /tmp/adobe-fonts
