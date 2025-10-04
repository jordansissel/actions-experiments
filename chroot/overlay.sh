#!/bin/sh

set -e
mkdir -p /overlay

mount -t tmpfs tmpfs /overlay

mkdir /overlay/_

# Copy root symlinks?

find / -maxdepth 1 -type l -print0 | xargs -0 sh -c 'cp -d "$@" /overlay/_/' -

paths="/usr /etc /var/lib"
for path in $paths; do
  name="$(echo $path | tr -d /)"

  mkdir -p "/overlay/upper/$path"
  mkdir -p "/overlay/work/$path"
  mkdir -p "/overlay/_/$path"

  mount -t overlay overlay -o "lowerdir=${path},upperdir=/overlay/upper/${path},workdir=/overlay/work/${path}" "/overlay/_/${path}"
done

mkdir /overlay/_/tmp
mkdir /overlay/_/proc
mount -t proc proc /overlay/_/proc

mkdir /overlay/_/dev
mount -o bind /dev /overlay/_/dev
mount -o bind /dev/pts /overlay/_/dev/pts
mount -o bind /dev/console /overlay/_/dev/console

mkdir /overlay/_/var/cache
mount -o bind /var/cache /overlay/_/var/cache

mkdir /overlay/_/var/log

# Inside docker, /etc/resolv.conf is often mounted from the outside.
if [ "$(stat -c "%d" /etc)" -ne "$(stat -c "%d" /etc/resolv.conf)" ]; then
  MOUNT_RESOLV_CONF=1
  mount -o bind /etc/resolv.conf /overlay/_/etc/resolv.conf
fi

chroot /overlay/_ "$@"

tar -zcf changes.tar.gz -C /overlay/upper/ .

if [ ! -z "$MOUNT_RESOLV_CONF" ]; then
  umount /overlay/_/etc/resolv.conf
fi

for path in /dev/pts /dev/console /dev /proc /usr /etc /var/lib /var/cache; do
  umount "/overlay/_/$path"
done

umount /overlay
