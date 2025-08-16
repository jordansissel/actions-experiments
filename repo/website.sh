#!/bin/sh

fail() {
    echo "$@"
    exit 1
}

set -e 

workdir="$1"
[ -z "$workdir" ] && fail "Missing argument for work directory"

base="$(dirname "$0")"
html="$(dirname "$0")"/../html

cd "$html"
# Change the jekyll uid to match ours?
# The jekyll in $PATH in this docker image will suexec to 'jekyll' which may not match our uid.
docker run --volume "$PWD:/srv/jekyll:z" --volume "$workdir:/workdir:z" jekyll/minimal sh -xc "usermod -u $(id -u) jekyll; jekyll build -d /workdir --disable-disk-cache"