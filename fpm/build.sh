#!/bin/sh
set -e

osrel() {
  field="$1"
  line="$(grep "^${field}=" /etc/os-release)"

  # Turn FOO="value" into just value
  echo "${line#${field}=}" | sed -re 's/^"|"$//g'
}

install_dependencies() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  echo "[Detected OS: $ID $VERSION]"
  case "${ID}" in
    ubuntu|debian) 
      apt-get update --quiet
      apt-get install -y --quiet ruby binutils
      ;;
    almalinux|rocky)
      dnf install -y $flags ruby-devel rpm-build;;
    fedora)
      dnf install -y ruby-devel rpm-build ;;
    * )
      echo "Unsupported OS: ${ID}"
      exit 1
      ;;
  esac
}

fpm_flags() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  case "${ID}" in
    ubuntu|debian) 
      echo "-t deb"
      echo "--depends rpm"
      echo "--depends binutils"
      ;;
    almalinux|rocky)
      echo "-t rpm"
      echo "--depends rpm-build"
      echo "--depends binutils"
      ;;
    fedora)
      echo "-t rpm"
      echo "--depends rpm-build"
      echo "--depends binutils"
      ;;
    * )
      echo "Unsupported OS: ${ID}"
      exit 1
      ;;
  esac
}

run() {
  if [ "$#" -eq 0 ] ; then
    echo "Usage: $0 <command> ..."
    echo 
    echo "Commands:"
    echo 
    echo 
    echo setup-dependencies - install any OS runtime dependencies needed by fpm
    echo setup-fpm - install fpm
    echo patch - patch anything needed for packaging
    echo package - package it
    exit 1
  fi

  version="${2:-1.16.0}"
  basedir="/tmp/build"
  installpath="/usr/lib/fpm"
  outdir="target"

  case "$1" in
    setup-dependencies)
      install_dependencies
      ;;
    setup-fpm)
      gem install --quiet --no-wrappers --install-dir "${basedir}" --bindir "${basedir}/bin" --no-document fpm -v "${version}"
      ;;
    patch)
      # Modify the fpm entry script to add our custom gem path
      sed -ie "1a Gem::Specification.dirs = Gem.paths.path.unshift('${installpath}')" "${basedir}/bin/fpm"
      ;;
    package)
      [ ! -d "$outdir" ] && mkdir "$outdir"

      GEM_PATH="${basedir}" "${basedir}/bin/fpm" \
        -s dir \
        --name "fpm" --version "${version}" \
        -C "${basedir}" \
        --architecture "all" \
        --package "${outdir}" \
        $(fpm_flags) \
        gems=${installpath} \
        specifications=${installpath} \
        bin/fpm=/usr/bin/fpm
      ;;
    all)
      run setup-dependencies
      run setup-fpm
      run patch
      run package
      ;;
    *)
      echo "Unknown command: $1"
      exit 1
      ;;
  esac
}

run "$@"