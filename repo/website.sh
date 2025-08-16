#!/bin/sh

fail() {
    echo "$@"
    exit 1
}

set -e 

source="$1"
destination="$2"
[ -z "$source" ] && fail "Missing argument for source directory"
[ -z "$destination" ] && fail "Missing argument for work directory"

docker run -i --volume "$source:/source:z" --volume "$destination:/destination:z" jekyll/minimal \
  sh -c "usermod -u $(id -u) jekyll; jekyll build -s /source -d /destination --disable-disk-cache"
# docker run -i --volume "$source:/source:z" --volume "$destination:/destination:z" jekyll/minimal sh -x <<SHELL
# ls -ld /source
# ls -ld /destination

# usermod -u $(id -u) jekyll

# jekyll build -s /source -d /destination --disable-disk-cache
# SHELL