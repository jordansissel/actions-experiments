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

setup() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  if [ ! -f "$1" ] ; then
    echo "ERROR: Cannot install package because the file doesn't exist: $1"
    exit 1
  fi

  echo "[Detected OS: $ID $VERSION]"
  case "${ID}" in
    ubuntu|debian) 
      apt-get update

      # apt-get install can install local files, but they have to appear to be a path.
      # So "apt-get install foo.deb" won't work because it only looks online,
      # but "apt-get install ./foo.deb" will work.
      file="$1"
      if [ "$(basename "$file")" = "$file" ] ; then
        file="./$file"
      fi

      apt-get install -y "$file"
      ;;
    almalinux|rocky|fedora)
      dnf install -y "$1"
      ;;
    * )
      echo "Unsupported OS: ${ID}"
      exit 1
      ;;
  esac
}

setup "$1"

fpm -s empty -t deb -n example
fpm -s empty -t rpm -n example