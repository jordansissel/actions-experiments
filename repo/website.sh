#!/bin/sh

fail() {
    echo "$@"
    exit 1
}

set -e 
set -x 

source="$1"
destination="$2"
[ -z "$source" ] && fail "Missing argument for source directory"
[ -z "$destination" ] && fail "Missing argument for work directory"
[ ! -d "$source" ] && fail "Source directory must exist: $source"
[ ! -d "$destination" ] && fail "Destination directory must exist: $destination"

docker run --volume "$source:/source:z" --volume "$destination:/destination:z" jekyll/minimal \
  sh -xc "usermod -u $(id -u) jekyll; find /source; jekyll build -s /source -d /destination --disable-disk-cache"