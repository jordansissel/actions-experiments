#!/bin/sh
set -e

osrel() {
  field="$1"
  line="$(grep "^${field}=" /etc/os-release)"

  # Turn FOO="value" into just value
  echo "${line#${field}=}" | sed -re 's/^"|"$//g'
}

setup() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  echo "[Detected OS: $ID $VERSION]"
  case "${ID}" in
    ubuntu|debian) 
      apt-get update
      apt-get install -y "$1"
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