#!/bin/sh

fail() {
    echo "$@"
    exit 1
}

set -e 

workdir="$1"
[ -z "$workdir" ] && fail "Missing argument for work directory"

base="$(dirname "$0")"
html="$(dirname "$base")"/html

set -x
pwd
ls -d $workdir
docker run --volume "$PWD:/srv/jekyll:z" --volume "$workdir:/workdir:z" jekyll/minimal sh -c "ls -ld /workdir; id; usermod -u $(id -u) jekyll; id; jekyll build -d /workdir --disable-disk-cache