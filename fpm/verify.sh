#!/bin/sh
set -e

osrel() {
  # Pull the value of the FIELD=VALUE out of /etc/os-release
  # Supported double-quoted values and removes the outer quotes
  value="$(sed -rne "s/^${1}=\"?([^\"]+)\"?$/\1/p" /etc/os-release)"
  if [ -z "$value" ] ; then
    echo "Error: Could not find $1 in /etc/os-release"
    exit 1
  fi
  echo "$value"
}

fail() {
    echo "$@"
    exit 1
}

flavor() {
  ID="$1"
  VERSION="$2"

  case "${ID}" in
    ubuntu|debian) echo "deb" ;;
    fedora|almalinux|rocky|amzn|almalinux|centos) echo "rpm" ;;
    *) fail "Unsupported/unexpected distro: ${ID}" ;;
  esac
}

setup() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  if [ ! -f "$1" ] ; then
    fail "Cannot install package because the file doesn't exist: $1"
  fi

  FLAVOR="$(flavor "$ID" "$VERSION")"

  echo "[Detected OS: $ID $VERSION]"
  case "${FLAVOR}" in
    deb) 
      apt-get update --quiet

      # apt-get install can install local files, but they have to appear to be a path.
      # So "apt-get install foo.deb" won't work because it only looks online,
      # but "apt-get install ./foo.deb" will work.
      file="$1"
      if [ "$(basename "$file")" = "$file" ] ; then
        file="./$file"
      fi

      apt-get install -y "$file"
      ;;
    rpm)
      ID="$(osrel ID)"
      VERSION="$(osrel VERSION_ID)"
      if [ "$ID" = "centos" -a "$VERSION" = "8" ] ; then
        echo "=> CentOS 8 detected. Patching yum repos."
        # CentOS 8 is vaulted/archived. Patch the yum repos to point there.
        sed -i -e '/^mirrorlist/d; s@#baseurl=http://mirror.centos.org@baseurl=http://vault.centos.org@' /etc/yum.repos.d/CentOS-*
      fi

      dnf install -y "$1"
      ;;
    * )
      fail "Unsupported OS flavor: ${FLAVOR}"
      ;;
  esac
}

setup "$1"

fpm -s empty -t deb -n example
fpm -s empty -t rpm -n example