#!/bin/sh

set -e
mkdir -p /overlay

mount -t tmpfs tmpfs /overlay

mkdir /overlay/_

# Copy root symlinks?

find / -maxdepth 1 -type l -print0 | xargs -0 sh -c 'cp -d "$@" /overlay/_/' -

paths="/usr /etc /var/lib"

overlay() {
  path="$1"
  echo "Mounting COW overlay for path: $path"
  mkdir -p "/overlay/upper/$path"
  mkdir -p "/overlay/work/$path"
  mkdir -p "/overlay/_/$path"

  mount -t overlay overlay -o "lowerdir=${path},upperdir=/overlay/upper/${path},workdir=/overlay/work/${path}" "/overlay/_/${path}"
}

for path in $paths; do
  overlay "$path"
done

# Any extra paths to overlay
for path in "$@"; do
  overlay "$path"
done

mkdir /overlay/_/tmp
chmod 1777 /overlay/_/tmp

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
  MOUNT_RESOLV_CONF=/overlay/_/etc/resolv.conf
  mount -o bind /etc/resolv.conf /overlay/_/etc/resolv.conf
elif [ -L /etc/resolv.conf ]; then
  resolv="$(readlink -f /etc/resolv.conf)"
  MOUNT_RESOLV_CONF="/overlay/_${resolv}"

  # Mount the linked location. Probably /run/systemd/resolv/stub-resolv.conf
  mkdir -p "/overlay/_$(dirname "$resolv")"
  touch "/overlay/_${resolv}"

  mount -o bind "$resolv" "/overlay/_${resolv}"
fi

# bash input from stdin.
chroot /overlay/_ bash -x

tar -zcf cow.tar.gz -C /overlay/upper/ .

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
