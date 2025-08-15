#!/bin/sh
set -e

fail() {
  echo "$@" >&2
  exit 1
}

osrel() {
  # Pull the value of the FIELD=VALUE out of /etc/os-release
  # Supported double-quoted values and removes the outer quotes
  value="$(sed -rne "s/^${1}=\"?([^\"]+)\"?$/\1/p" /etc/os-release)"
  if [ -z "$value" ] ; then
    fail "Error: Could not find $1 in /etc/os-release"
  fi
  echo "$value"
}

refresh_packages() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  case "${ID}" in
    ubuntu|debian) apt-get update --quiet ;;
    fedora|almalinux|rocky) dnf makecache ;;
    *)
      fail "Unsupported OS: ${ID}"
      ;;
  esac
}

install_dependencies() {
  ID="$(osrel ID)"
  VERSION="$(osrel VERSION_ID)"

  echo "[Detected OS: $ID $VERSION]"
  case "${ID}" in
    ubuntu|debian) 
      apt-get install -y --quiet ruby binutils
      ;;
    fedora|almalinux|rocky)
      dnf install -y ruby-devel rpm-build
      ;;
    *) fail "Unsupported OS: ${ID}" ;;
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
    fedora|almalinux|rocky)
      echo "-t rpm"
      echo "--depends rpm-build"
      echo "--depends binutils"
      echo "--depends ruby"
      ;;
    * )
      fail "Unsupported OS: ${ID}"
      ;;
  esac
}

run() {
  if [ "$#" -eq 0 ] ; then
    cat <<USAGE
  Usage: $0 <command> ...
  
  Commands:
  
  refresh-packages - runs apt-get update or dnf makecache, etc.
  setup-dependencies - install any OS runtime dependencies needed by fpm
  setup-fpm - install fpm
  patch - patch anything needed for packaging
  package - package it
  buildinfo - note build information (distro version, etc) into a file: package.json
USAGE
    exit 1
  fi

  version="${2:-1.16.0}"
  basedir="/tmp/build"
  installpath="/usr/lib/fpm"
  outdir="target"

  case "$1" in
    refresh-packages)
      refresh_packages
      ;;
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
      run refresh-packages
      run setup-dependencies
      run setup-fpm
      run patch
      run package
      run buildinfo
      ;;
    *)
      fail "Unknown command: $1"
      ;;
  esac
}

run "$@"