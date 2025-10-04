#!/bin/sh

set -e
mkdir -p /overlay

mount -t tmpfs tmpfs /overlay

mkdir /overlay/_

# Copy root symlinks?

find / -maxdepth 1 -type l -print0 | xargs -0 sh -c 'cp -d "$@" /overlay/_/' -

paths="/usr /etc /var/lib"
for path in $paths; do
  mkdir -p "/overlay/upper/$path"
  mkdir -p "/overlay/work/$path"
  mkdir -p "/overlay/_/$path"

  mount -t overlay overlay -o "lowerdir=${path},upperdir=/overlay/upper/${path},workdir=/overlay/work/${path}" "/overlay/_/${path}"
done

mkdir /overlay/_/tmp
mkdir /overlay/_/run

mkdir /overlay/_/proc
mount -t proc proc /overlay/_/proc

mkdir /overlay/_/dev
mount -o bind /dev /overlay/_/dev
mount -o bind /dev/pts /overlay/_/dev/pts

if [ -e /dev/console ]; then
  mount -o bind /dev/console /overlay/_/dev/console
fi

mkdir /overlay/_/var/cache
mount -o bind /var/cache /overlay/_/var/cache

mkdir /overlay/_/var/log

# Inside docker, /etc/resolv.conf is often mounted from the outside.
if [ "$(stat -c "%d" /etc)" -ne "$(stat -c "%d" /etc/resolv.conf)" ]; then
  MOUNT_RESOLV_CONF=1
elif [ -L /etc/resolv.conf ]; then
  MOUNT_RESOLV_CONF=1
fi

mount -o bind /etc/resolv.conf /overlay/_/etc/resolv.conf

echo "Host:"
ls -ld /etc/resolv.conf
grep . /etc/resolv.conf

grep . /etc/nsswitch.conf

echo "Chroot begins:"
# bash input from stdin.
chroot /overlay/_ bash

tar -zcf /var/cache/cow.tar.gz -C /overlay/upper/ .

if [ -n "$MOUNT_RESOLV_CONF" ]; then
  umount /overlay/_/etc/resolv.conf
fi

if [ -e /dev/console ]; then
  umount /overlay/_/dev/console
fi

for path in /dev/pts /dev /proc /usr /etc /var/lib /var/cache; do
  umount "/overlay/_/$path"
done

umount /overlay
