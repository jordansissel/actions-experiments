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
      echo "--depends ruby"
      ;;
    almalinux|rocky)
      echo "-t rpm"
      echo "--depends rpm-build"
      echo "--depends binutils"
      echo "--depends ruby"
      ;;
    fedora)
      echo "-t rpm"
      echo "--depends rpm-build"
      echo "--depends binutils"
      echo "--depends ruby"
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
    buildinfo)
      cat > "${outdir}/package.json" << METADATA
        {
          "distro": "$(osrel ID)",
          "version": "$(osrel VERSION_ID)",
          "codename": "$(osrel VERSION_CODENAME)"
        }
METADATA
      ;;
    package)
      [ ! -d "$outdir" ] && mkdir "$outdir"

      GEM_PATH="${basedir}" "${basedir}/bin/fpm" \
        -s dir \
        --name "fpm" --version "${version}" \
        -C "${basedir}" \
        --architecture "all" \
        --package "${outdir}" \
        --iteration "1-$(osrel ID)$(osrel VERSION_ID)" \
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
      run buildinfo
      ;;
    *)
      echo "Unknown command: $1"
      exit 1
      ;;
  esac
}

run "$@"