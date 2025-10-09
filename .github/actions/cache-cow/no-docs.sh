#!/bin/sh

set -e

if [ "$#" -ne 1 ] ; then
  echo "Usage: $0 <setup | teardown>"
  exit 1
fi

case "$1" in
setup)
  echo "path-exclude=/usr/share/doc/*" >/etc/dpkg/dpkg.cfg.d/01cachecow-nodocs
  echo "path-exclude=/usr/share/man/*" >>/etc/dpkg/dpkg.cfg.d/01cachecow-nodocs
  echo "man-db  man-db/auto-update      boolean false" | sudo debconf-set-selections
  ;;
teardown)
  rm /etc/dpkg/dpkg.cfg.d/01cachecow-nodocs
  echo "man-db  man-db/auto-update      boolean true" | sudo debconf-set-selections
  ;;

*)
  echo "$0: Unknown command: '$1'"
  echo "Usage: $0 <setup | teardown>"
  exit 1
  ;;
esac
