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

  mkdir -p "/overlay/$name"
  mkdir "/overlay/$name/upper"
  mkdir "/overlay/$name/work"

  mkdir -p "/overlay/_/${path}"

  mount -t overlay overlay -o "lowerdir=${path},upperdir=/overlay/${name}/upper,workdir=/overlay/${name}/work" "/overlay/_/${path}"
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

# Inside docker, /etc/resolv.conf is often mounted from the outside.
if [ "$(stat -c "%d" /etc)" -ne "$(stat -c "%d" /etc/resolv.conf)" ]; then
  mount -o bind /etc/resolv.conf /overlay/_/etc/resolv.conf
fi

chroot /overlay/_ "$@"

#for path in $paths; do
#umount "/overlay/_/${path}"
#done
