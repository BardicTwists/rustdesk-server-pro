#!/bin/bash

# shellcheck disable=2034,2059,2164
true

TLS=""
if command -v ldconfig &> /dev/null; then
    if ldconfig -p | grep -q "libssl.so.3"; then
        TLS="-nativetls"
    fi
fi

# Get username
usern=$(whoami) # not used btw ... yet

# Get current release version
RDLATEST=$(curl https://api.github.com/repos/rustdesk/rustdesk-server-pro/releases/latest -s | grep "tag_name"| awk '{print substr($2, 2, length($2)-3) }')

# Below current version caused different strange problem, e.g. https://github.com/rustdesk/rustdesk-server-pro/discussions/687
# RDCURRENT=$(/usr/bin/hbbr --version | sed -r 's/hbbr (.*)/\1/')

#if [ $RDLATEST == $RDCURRENT ]; then
#    echo "Same version, no need to update."
#    exit 0
#fi

sudo systemctl stop rustdesk-hbbs.service
sudo systemctl stop rustdesk-hbbr.service
sleep 20

ARCH=$(uname -m)


# Identify OS
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    UPSTREAM_ID=${ID_LIKE,,}

    # Fallback to ID_LIKE if ID was not 'ubuntu' or 'debian'
    if [ "${UPSTREAM_ID}" != "debian" ] && [ "${UPSTREAM_ID}" != "ubuntu" ]; then
        UPSTREAM_ID="$(echo ${ID_LIKE,,} | sed s/\"//g | cut -d' ' -f1)"
    fi

elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian, Ubuntu, etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSE-release ]; then
    # Older SuSE, etc.
    OS=SuSE
    VER=$(cat /etc/SuSE-release)
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS=RedHat
    VER=$(cat /etc/redhat-release)
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi


# Output debugging info if $DEBUG set
if [ "$DEBUG" = "true" ]; then
    echo "OS: $OS"
    echo "VER: $VER"
    echo "UPSTREAM_ID: $UPSTREAM_ID"
    exit 0
fi


if ! [ -e /var/lib/rustdesk-server/ ]; then
        echo "No directory /var/lib/rustdesk-server/ found. No update of RustDesk possible (use install.sh script?)"
        exit 4
else
        :
fi

cd /var/lib/rustdesk-server/
rm -rf static/

echo "Upgrading RustDesk Server"
if [ "${ARCH}" = "x86_64" ] ; then
wget https://github.com/rustdesk/rustdesk-server-pro/releases/download/${RDLATEST}/rustdesk-server-linux-amd64${TLS}.tar.gz
tar -xf rustdesk-server-linux-amd64${TLS}.tar.gz
mv amd64${TLS}/static /var/lib/rustdesk-server/
sudo mv amd64${TLS}/hbbr /usr/bin/
sudo mv amd64${TLS}/hbbs /usr/bin/
sudo mv amd64${TLS}/rustdesk-utils /usr/bin/
rm -rf amd64${TLS}/
rm -rf rustdesk-server-linux-amd64${TLS}.tar.gz
elif [ "${ARCH}" = "armv7l" ] ; then
wget "https://github.com/rustdesk/rustdesk-server-pro/releases/download/${RDLATEST}/rustdesk-server-linux-armv7.tar.gz"
tar -xf rustdesk-server-linux-armv7.tar.gz
mv armv7/static /var/lib/rustdesk-server/
sudo mv armv7/hbbr /usr/bin/
sudo mv armv7/hbbs /usr/bin/
sudo mv armv7/rustdesk-utils /usr/bin/
rm -rf armv7/
rm -rf rustdesk-server-linux-armv7.tar.gz
elif [ "${ARCH}" = "aarch64" ] ; then
wget "https://github.com/rustdesk/rustdesk-server-pro/releases/download/${RDLATEST}/rustdesk-server-linux-arm64v8${TLS}.tar.gz"
tar -xf rustdesk-server-linux-arm64v8${TLS}.tar.gz
mv arm64v8${TLS}/static /var/lib/rustdesk-server/
sudo mv arm64v8${TLS}/hbbr /usr/bin/
sudo mv arm64v8${TLS}/hbbs /usr/bin/
sudo mv arm64v8${TLS}/rustdesk-utils /usr/bin/
rm -rf arm64v8${TLS}/
rm -rf rustdesk-server-linux-arm64v8${TLS}.tar.gz
fi

sudo chmod +x /usr/bin/hbbs
sudo chmod +x /usr/bin/hbbr
sudo chmod +x /usr/bin/rustdesk-utils

sudo systemctl start rustdesk-hbbs.service
sudo systemctl start rustdesk-hbbr.service

while ! [[ $CHECK_RUSTDESK_READY ]]; do
  CHECK_RUSTDESK_READY=$(sudo systemctl status rustdesk-hbbr.service | grep "Active: active (running)")
  echo -ne "RustDesk Relay not ready yet...${NC}\n"
  sleep 3
done

echo -e "Updates are complete"
