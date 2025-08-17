#!/bin/sh

#postinst configure most-recently-configured-version
echo "After install: $@"
if [ "$1" = "configure" ] ; then
    distro="$(sed -rne 's/^ID="?([^"]+)"?$/\1/p' /etc/os-release)"
    codename="$(sed -rne 's/^VERSION_CODENAME="?([^"]+)"?$/\1/p' /etc/os-release)"
    
    sed -i -e "s/^Suites:.*/Suites: $codename/; /^URIs:/ { s/DISTRO/$distro/ }" /etc/apt/sources.list.d/fpm.sources
fi
